import Foundation
import FirebaseAuth
import FirebaseFirestore

@Observable
@MainActor
final class FirestoreService {
    static let shared = FirestoreService()

    var towels: [Towel] = []
    var isLoading = false
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

    private func userTowelsCollection() -> CollectionReference? {
        guard let userId else { return nil }
        return db.collection("users").document(userId).collection("towels")
    }

    // MARK: - Subscribe

    func startListening() {
        guard let collection = userTowelsCollection() else { return }

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
              let collection = userTowelsCollection() else { return }

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
              let collection = userTowelsCollection() else { return }

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

    func addTowel(name: String, location: String, iconName: String, exchangeIntervalDays: Int) async throws -> String {
        guard let collection = userTowelsCollection() else {
            throw FirestoreError.notAuthenticated
        }

        let data: [String: Any] = [
            "name": name,
            "location": location,
            "iconName": iconName,
            "exchangeIntervalDays": exchangeIntervalDays,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        let docRef = try await collection.addDocument(data: data)
        return docRef.documentID
    }

    func updateTowel(_ towelId: String, name: String, location: String, iconName: String, exchangeIntervalDays: Int) async throws {
        guard let collection = userTowelsCollection() else {
            throw FirestoreError.notAuthenticated
        }

        try await collection.document(towelId).updateData([
            "name": name,
            "location": location,
            "iconName": iconName,
            "exchangeIntervalDays": exchangeIntervalDays,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func deleteTowel(_ towelId: String) async throws {
        guard let collection = userTowelsCollection() else {
            throw FirestoreError.notAuthenticated
        }

        // Delete subcollections first
        let recordsSnapshot = try await collection.document(towelId).collection("records").getDocuments()
        for doc in recordsSnapshot.documents {
            try await doc.reference.delete()
        }

        let checksSnapshot = try await collection.document(towelId).collection("conditionChecks").getDocuments()
        for doc in checksSnapshot.documents {
            try await doc.reference.delete()
        }

        try await collection.document(towelId).delete()
    }

    // MARK: - Exchange Record

    func addRecord(towelId: String, exchangedAt: Date, note: String?) async throws -> String {
        guard let collection = userTowelsCollection() else {
            throw FirestoreError.notAuthenticated
        }

        var data: [String: Any] = [
            "exchangedAt": Timestamp(date: exchangedAt),
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let note, !note.isEmpty {
            data["note"] = note
        }

        let docRef = try await collection.document(towelId).collection("records").addDocument(data: data)
        return docRef.documentID
    }

    func deleteRecord(towelId: String, recordId: String) async throws {
        guard let collection = userTowelsCollection() else {
            throw FirestoreError.notAuthenticated
        }

        try await collection.document(towelId).collection("records").document(recordId).delete()
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
        guard let collection = userTowelsCollection() else {
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
        guard let collection = userTowelsCollection() else {
            throw FirestoreError.notAuthenticated
        }

        try await collection.document(towelId).collection("conditionChecks").document(checkId).updateData([
            "photoURL": photoURL
        ])
    }

    func deleteConditionCheck(towelId: String, checkId: String) async throws {
        guard let collection = userTowelsCollection() else {
            throw FirestoreError.notAuthenticated
        }

        try await collection.document(towelId).collection("conditionChecks").document(checkId).delete()
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
