import Foundation
import FirebaseAuth
import FirebaseFirestore

@Observable
@MainActor
final class FirestoreService {
    static let shared = FirestoreService()

    var towels: [Towel] = []
    var isLoading = true
    var errorMessage: String?

    private let db = Firestore.firestore()
    private var towelListener: ListenerRegistration?
    private var recordListeners: [String: ListenerRegistration] = [:]
    private var conditionCheckListeners: [String: ListenerRegistration] = [:]

    private init() {}

    // MARK: - User ID

    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    private func towelsCollection() -> CollectionReference? {
        guard let userId else { return nil }

        if let groupId = GroupService.shared.groupId {
            return db.collection("groups").document(groupId).collection("towels")
        }
        return db.collection("users").document(userId).collection("towels")
    }

    /// Personal towels collection (for account deletion only — always uses solo path)
    private func personalTowelsCollection() -> CollectionReference? {
        guard let userId else { return nil }
        return db.collection("users").document(userId).collection("towels")
    }

    // MARK: - Subscribe

    func startListening() {
        guard let collection = towelsCollection() else { return }

        stopListening()
        isLoading = true

        towelListener = collection
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    self.errorMessage = "データの読み込みに失敗しました: \(error.localizedDescription)"
                    self.isLoading = false
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.towels = []
                    self.isLoading = false
                    return
                }

                var newTowels = documents.compactMap { doc -> Towel? in
                    try? doc.data(as: Towel.self)
                }

                // Carry over existing subcollection data while re-subscribing
                for i in newTowels.indices {
                    if let existing = self.towels.first(where: { $0.id == newTowels[i].id }) {
                        newTowels[i].records = existing.records
                        newTowels[i].conditionChecks = existing.conditionChecks
                    }
                }

                self.towels = newTowels
                self.isLoading = false

                // Subscribe to subcollections for each towel
                for towel in newTowels {
                    guard let towelId = towel.id else { continue }
                    self.subscribeToRecords(towelId: towelId)
                    self.subscribeToConditionChecks(towelId: towelId)
                }

                // Clean up listeners for removed towels
                let currentIds = Set(newTowels.compactMap(\.id))
                for key in self.recordListeners.keys where !currentIds.contains(key) {
                    self.recordListeners[key]?.remove()
                    self.recordListeners.removeValue(forKey: key)
                }
                for key in self.conditionCheckListeners.keys where !currentIds.contains(key) {
                    self.conditionCheckListeners[key]?.remove()
                    self.conditionCheckListeners.removeValue(forKey: key)
                }
            }
    }

    func stopListening() {
        towelListener?.remove()
        towelListener = nil
        recordListeners.values.forEach { $0.remove() }
        recordListeners.removeAll()
        conditionCheckListeners.values.forEach { $0.remove() }
        conditionCheckListeners.removeAll()
    }

    private func subscribeToRecords(towelId: String) {
        guard recordListeners[towelId] == nil,
              let collection = towelsCollection() else { return }

        let listener = collection.document(towelId).collection("records")
            .order(by: "exchangedAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let documents = snapshot?.documents else { return }
                let records = documents.compactMap { try? $0.data(as: ExchangeRecord.self) }
                if let index = self.towels.firstIndex(where: { $0.id == towelId }) {
                    self.towels[index].records = records
                }
            }

        recordListeners[towelId] = listener
    }

    private func subscribeToConditionChecks(towelId: String) {
        guard conditionCheckListeners[towelId] == nil,
              let collection = towelsCollection() else { return }

        let listener = collection.document(towelId).collection("conditionChecks")
            .order(by: "checkedAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let documents = snapshot?.documents else { return }
                let checks = documents.compactMap { try? $0.data(as: ConditionCheck.self) }
                if let index = self.towels.firstIndex(where: { $0.id == towelId }) {
                    self.towels[index].conditionChecks = checks
                }
            }

        conditionCheckListeners[towelId] = listener
    }

    // MARK: - Towel CRUD

    func addTowel(name: String, location: String, iconName: String, exchangeIntervalDays: Int) throws -> String {
        guard let collection = towelsCollection() else {
            throw FirestoreError.notAuthenticated
        }

        let docRef = collection.document()
        docRef.setData([
            "name": name,
            "location": location,
            "iconName": iconName,
            "exchangeIntervalDays": exchangeIntervalDays,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        return docRef.documentID
    }

    func updateTowel(_ towelId: String, name: String, location: String, iconName: String, exchangeIntervalDays: Int) throws {
        guard let collection = towelsCollection() else {
            throw FirestoreError.notAuthenticated
        }

        collection.document(towelId).updateData([
            "name": name,
            "location": location,
            "iconName": iconName,
            "exchangeIntervalDays": exchangeIntervalDays,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func deleteTowel(_ towelId: String) throws {
        guard let collection = towelsCollection() else {
            throw FirestoreError.notAuthenticated
        }

        // Delete subcollections using in-memory data (no server round-trip)
        if let towel = towels.first(where: { $0.id == towelId }) {
            for record in towel.records {
                if let recordId = record.id {
                    collection.document(towelId).collection("records").document(recordId).delete()
                }
            }
            for check in towel.conditionChecks {
                if let checkId = check.id {
                    collection.document(towelId).collection("conditionChecks").document(checkId).delete()
                }
            }
        }

        collection.document(towelId).delete()
    }

    /// Delete all towels and their subcollections for the current user
    func deleteAllTowels() {
        let towelIds = towels.compactMap(\.id)
        for towelId in towelIds {
            try? deleteTowel(towelId)
        }
    }

    /// Delete the user document itself
    func deleteUserDocument() async throws {
        guard let userId else {
            throw FirestoreError.notAuthenticated
        }
        // dailyAssessments サブコレクションを削除（Firestoreは親削除時に自動削除しない）
        let assessments = try await db.collection("users").document(userId)
            .collection("dailyAssessments").getDocuments()
        for doc in assessments.documents {
            try? await doc.reference.delete()
        }
        try await db.collection("users").document(userId).delete()
    }

    // MARK: - Exchange Record

    func addRecord(towelId: String, exchangedAt: Date, note: String?) throws -> String {
        guard let collection = towelsCollection() else {
            throw FirestoreError.notAuthenticated
        }

        let batch = db.batch()

        let recordRef = collection.document(towelId).collection("records").document()
        var data: [String: Any] = [
            "exchangedAt": Timestamp(date: exchangedAt),
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let note, !note.isEmpty {
            data["note"] = note
        }
        batch.setData(data, forDocument: recordRef)

        let towelRef = collection.document(towelId)
        batch.updateData([
            "lastExchangedAt": Timestamp(date: exchangedAt),
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: towelRef)

        batch.commit { _ in }
        return recordRef.documentID
    }

    func deleteRecord(towelId: String, recordId: String) throws {
        guard let collection = towelsCollection() else {
            throw FirestoreError.notAuthenticated
        }

        collection.document(towelId).collection("records").document(recordId).delete()

        // Recalculate lastExchangedAt from in-memory records (no server round-trip)
        let remainingRecords = towels.first(where: { $0.id == towelId })?.records
            .filter { $0.id != recordId }
            .sorted { ($0.exchangedAt ?? .distantPast) > ($1.exchangedAt ?? .distantPast) }

        let newLastExchangedAt: Any = remainingRecords?.first?.exchangedAt
            .map { Timestamp(date: $0) } ?? FieldValue.delete()

        collection.document(towelId).updateData([
            "lastExchangedAt": newLastExchangedAt,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    // MARK: - Condition Check

    func saveConditionCheck(
        towelId: String,
        photoURL: String?,
        overallScore: Int,
        colorFadingScore: Int,
        stainScore: Int,
        fluffinessScore: Int,
        frayingScore: Int,
        comment: String,
        recommendation: String
    ) async throws -> String {
        guard let collection = towelsCollection() else {
            throw FirestoreError.notAuthenticated
        }

        var data: [String: Any] = [
            "overallScore": overallScore,
            "colorFadingScore": colorFadingScore,
            "stainScore": stainScore,
            "fluffinessScore": fluffinessScore,
            "frayingScore": frayingScore,
            "comment": comment,
            "recommendation": recommendation,
            "checkedAt": FieldValue.serverTimestamp()
        ]
        if let photoURL {
            data["photoURL"] = photoURL
        }

        let docRef = try await collection.document(towelId).collection("conditionChecks").addDocument(data: data)
        return docRef.documentID
    }

    func updateConditionCheckPhotoURL(towelId: String, checkId: String, photoURL: String) async throws {
        guard let collection = towelsCollection() else {
            throw FirestoreError.notAuthenticated
        }

        try await collection.document(towelId).collection("conditionChecks").document(checkId).updateData([
            "photoURL": photoURL
        ])
    }

    func deleteConditionCheck(towelId: String, checkId: String) throws {
        guard let collection = towelsCollection() else {
            throw FirestoreError.notAuthenticated
        }

        collection.document(towelId).collection("conditionChecks").document(checkId).delete()
    }

    // MARK: - Daily Assessment Limit

    private var todayDateKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "ja_JP")
        f.timeZone = TimeZone.current
        return f.string(from: Date())
    }

    func getDailyAssessmentCount() async throws -> Int {
        guard let userId else {
            throw FirestoreError.notAuthenticated
        }
        let docRef = db.collection("users").document(userId)
            .collection("dailyAssessments").document(todayDateKey)
        let snapshot = try await docRef.getDocument()
        return snapshot.data()?["count"] as? Int ?? 0
    }

    func incrementDailyAssessmentCount() async throws {
        guard let userId else {
            throw FirestoreError.notAuthenticated
        }
        let docRef = db.collection("users").document(userId)
            .collection("dailyAssessments").document(todayDateKey)
        try await docRef.setData(["count": FieldValue.increment(Int64(1))], merge: true)
    }
}

enum FirestoreError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "サインインが必要です"
        }
    }
}
