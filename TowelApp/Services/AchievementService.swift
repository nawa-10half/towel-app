import Foundation
import Observation
import FirebaseAuth
import FirebaseFirestore

@Observable
@MainActor
final class AchievementService {
    static let shared = AchievementService()

    private(set) var unlocked: [String: UnlockedAchievement] = [:]
    private(set) var groupUnlocked: [String: GroupUnlockedAchievement] = [:]

    /// Newly unlocked IDs awaiting toast display. UI drains this queue.
    var pendingToasts: [String] = []

    var pinnedBadgeId: String?

    // Counter cache from users doc
    private(set) var totalExchangeCount: Int = 0
    private(set) var totalConditionCheckCount: Int = 0
    private(set) var conditionScoreSum: Int = 0
    private(set) var conditionScoreCount: Int = 0

    // Group counter cache
    private(set) var groupTotalExchangeCount: Int = 0

    private let db = Firestore.firestore()
    private var userListener: ListenerRegistration?
    private var achievementsListener: ListenerRegistration?
    private var groupAchievementsListener: ListenerRegistration?
    private var groupDocListener: ListenerRegistration?

    private static let retroactiveFlagKey = "achievements_migrated_v1"

    private init() {}

    private var userId: String? { Auth.auth().currentUser?.uid }

    // MARK: - Derived state

    var unlockedCount: Int { unlocked.count + groupUnlocked.count }
    var totalCount: Int { AchievementCatalog.all.count }

    func isUnlocked(_ id: String) -> Bool {
        unlocked[id] != nil || groupUnlocked[id] != nil
    }

    var displayBadge: AchievementDefinition? {
        if let pinnedBadgeId,
           let def = AchievementCatalog.definition(for: pinnedBadgeId),
           isUnlocked(pinnedBadgeId) {
            return def
        }
        let unlockedDefs = AchievementCatalog.all.filter { isUnlocked($0.id) }
        return unlockedDefs.max { lhs, rhs in
            if lhs.tier != rhs.tier { return lhs.tier < rhs.tier }
            let lhsDate = unlocked[lhs.id]?.unlockedAt ?? groupUnlocked[lhs.id]?.unlockedAt ?? .distantPast
            let rhsDate = unlocked[rhs.id]?.unlockedAt ?? groupUnlocked[rhs.id]?.unlockedAt ?? .distantPast
            return lhsDate < rhsDate
        }
    }

    // MARK: - Listening

    func startListening() {
        guard let userId else { return }
        stopListening()

        let userRef = db.collection("users").document(userId)
        userListener = userRef.addSnapshotListener { [weak self] snapshot, _ in
            guard let self, let data = snapshot?.data() else { return }
            self.totalExchangeCount = data["totalExchangeCount"] as? Int ?? 0
            self.totalConditionCheckCount = data["totalConditionCheckCount"] as? Int ?? 0
            self.conditionScoreSum = data["conditionScoreSum"] as? Int ?? 0
            self.conditionScoreCount = data["conditionScoreCount"] as? Int ?? 0
            self.pinnedBadgeId = data["pinnedBadgeId"] as? String
        }

        achievementsListener = userRef.collection("achievements")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let documents = snapshot?.documents else { return }
                var map: [String: UnlockedAchievement] = [:]
                for doc in documents {
                    if let item = try? doc.data(as: UnlockedAchievement.self), let id = item.id {
                        map[id] = item
                    }
                }
                self.unlocked = map
            }

        if let groupId = GroupService.shared.groupId {
            subscribeGroupAchievements(groupId: groupId)
        }
    }

    func stopListening() {
        userListener?.remove()
        userListener = nil
        achievementsListener?.remove()
        achievementsListener = nil
        groupAchievementsListener?.remove()
        groupAchievementsListener = nil
        groupDocListener?.remove()
        groupDocListener = nil
        unlocked = [:]
        groupUnlocked = [:]
        totalExchangeCount = 0
        totalConditionCheckCount = 0
        conditionScoreSum = 0
        conditionScoreCount = 0
        groupTotalExchangeCount = 0
    }

    func subscribeGroupAchievements(groupId: String) {
        groupAchievementsListener?.remove()
        groupDocListener?.remove()

        let groupRef = db.collection("groups").document(groupId)
        groupAchievementsListener = groupRef.collection("achievements")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let documents = snapshot?.documents else { return }
                var map: [String: GroupUnlockedAchievement] = [:]
                for doc in documents {
                    if let item = try? doc.data(as: GroupUnlockedAchievement.self), let id = item.id {
                        map[id] = item
                    }
                }
                self.groupUnlocked = map
            }

        groupDocListener = groupRef.addSnapshotListener { [weak self] snapshot, _ in
            guard let self, let data = snapshot?.data() else { return }
            self.groupTotalExchangeCount = data["totalExchangeCount"] as? Int ?? 0
        }
    }

    // MARK: - Profile

    func updatePinnedBadge(_ badgeId: String?) async {
        guard let userId else { return }
        self.pinnedBadgeId = badgeId
        let data: [String: Any] = [
            "pinnedBadgeId": badgeId ?? FieldValue.delete()
        ]
        try? await db.collection("users").document(userId).setData(data, merge: true)

        if let groupId = GroupService.shared.groupId {
            try? await db.collection("groups").document(groupId)
                .collection("members").document(userId)
                .updateData(data)
        }
    }

    // MARK: - Unlock write

    private func unlock(_ definition: AchievementDefinition, silently: Bool = false) async {
        guard unlocked[definition.id] == nil else { return }
        guard let userId else { return }

        let data: [String: Any] = [
            "unlockedAt": FieldValue.serverTimestamp(),
            "seen": silently,
            "tier": String(definition.tier.rawValue)
        ]
        try? await db.collection("users").document(userId)
            .collection("achievements").document(definition.id)
            .setData(data)

        if !silently {
            pendingToasts.append(definition.id)
        }
    }

    private func unlockGroup(_ definition: AchievementDefinition) async {
        guard groupUnlocked[definition.id] == nil else { return }
        guard let userId, let groupId = GroupService.shared.groupId else { return }

        let data: [String: Any] = [
            "unlockedAt": FieldValue.serverTimestamp(),
            "unlockedBy": userId
        ]
        try? await db.collection("groups").document(groupId)
            .collection("achievements").document(definition.id)
            .setData(data)

        pendingToasts.append(definition.id)
    }

    // MARK: - Evaluation

    func evaluateAfterExchange() async {
        await evaluate(categories: [.exchange, .group])
    }

    func evaluateAfterConditionCheck() async {
        await evaluate(categories: [.condition])
    }

    func evaluateAfterGroupAction() async {
        await evaluate(categories: [.group])
    }

    func evaluateAfterProPurchase() async {
        await evaluate(categories: [.milestone, .condition])
    }

    func evaluateAll() async {
        await evaluate(categories: Set(AchievementCatalog.all.map(\.category)))
    }

    private func evaluate(categories: Set<AchievementCategory>, silently: Bool = false) async {
        let isPro = StoreService.shared.isPro
        let inGroup = GroupService.shared.groupId != nil

        for def in AchievementCatalog.all where categories.contains(def.category) {
            if def.isProOnly && !isPro { continue }

            let satisfied: Bool
            switch def.requirement {
            case .exchangeCount(let n):
                satisfied = totalExchangeCount >= n
            case .conditionCheckCount(let n):
                satisfied = totalConditionCheckCount >= n
            case .averageScore(let min, let minChecks):
                guard conditionScoreCount >= minChecks else { satisfied = false; break }
                let avg = Double(conditionScoreSum) / Double(conditionScoreCount)
                satisfied = avg >= min
            case .allTowelsChecked:
                let towels = FirestoreService.shared.towels
                satisfied = !towels.isEmpty && towels.allSatisfy { $0.latestConditionCheck != nil }
            case .firstGroupJoin:
                satisfied = inGroup
            case .firstGroupCreate:
                satisfied = isGroupCreator()
            case .proPurchase:
                satisfied = isPro
            case .groupExchangeCount(let n):
                satisfied = groupTotalExchangeCount >= n
            case .groupAllMembersActive:
                satisfied = groupAllMembersHaveExchanged()
            }

            if satisfied {
                if def.isGroupAchievement {
                    await unlockGroup(def)
                } else {
                    await unlock(def, silently: silently)
                }
            }
        }
    }

    private func isGroupCreator() -> Bool {
        guard let userId, let group = GroupService.shared.group else { return false }
        return group.createdBy == userId
    }

    private func groupAllMembersHaveExchanged() -> Bool {
        let members = GroupService.shared.members
        guard members.count >= 2 else { return false }
        return members.allSatisfy { ($0.exchangeCount ?? 0) > 0 }
    }

    // MARK: - Retroactive Migration

    func performRetroactiveEvaluation() async {
        guard let userId else { return }
        guard !UserDefaults.standard.bool(forKey: Self.retroactiveFlagKey) else { return }

        let userRef = db.collection("users").document(userId)
        let inGroup = GroupService.shared.groupId != nil

        var exchangeCount = 0
        var checkCount = 0
        var scoreSum = 0

        let towelsCollection: CollectionReference
        if let groupId = GroupService.shared.groupId {
            towelsCollection = db.collection("groups").document(groupId).collection("towels")
        } else {
            towelsCollection = userRef.collection("towels")
        }

        do {
            let towels = try await towelsCollection.getDocuments()
            for towelDoc in towels.documents {
                let records = try await towelDoc.reference.collection("records").getDocuments()
                exchangeCount += records.documents.count

                let checks = try await towelDoc.reference.collection("conditionChecks").getDocuments()
                checkCount += checks.documents.count
                for check in checks.documents {
                    if let score = check.data()["overallScore"] as? Int {
                        scoreSum += score
                    }
                }
            }
        } catch {
            return
        }

        // Write counters to users doc (merge: true — only set the fields we computed).
        // We overwrite rather than increment so retroactive can't double count.
        try? await userRef.setData([
            "totalExchangeCount": exchangeCount,
            "totalConditionCheckCount": checkCount,
            "conditionScoreSum": scoreSum,
            "conditionScoreCount": checkCount
        ], merge: true)

        self.totalExchangeCount = exchangeCount
        self.totalConditionCheckCount = checkCount
        self.conditionScoreSum = scoreSum
        self.conditionScoreCount = checkCount

        UserDefaults.standard.set(true, forKey: Self.retroactiveFlagKey)

        // Silent evaluation — no toasts for already-earned progress
        await evaluate(categories: Set(AchievementCatalog.all.map(\.category)), silently: true)
    }
}
