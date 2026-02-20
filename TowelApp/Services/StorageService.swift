import Foundation
import FirebaseAuth
import FirebaseStorage
import UIKit

@MainActor
final class StorageService {
    static let shared = StorageService()

    private let storage = Storage.storage()

    private init() {}

    // MARK: - Path Helper

    private func conditionPhotoPath(towelId: String, checkId: String) -> String? {
        guard let userId = Auth.auth().currentUser?.uid else { return nil }

        if let groupId = GroupService.shared.groupId {
            return "groups/\(groupId)/towels/\(towelId)/conditions/\(checkId).jpg"
        }
        return "users/\(userId)/towels/\(towelId)/conditions/\(checkId).jpg"
    }

    /// Upload a condition check photo and return the download URL
    func uploadConditionPhoto(
        towelId: String,
        checkId: String,
        image: UIImage
    ) async throws -> String {
        guard let path = conditionPhotoPath(towelId: towelId, checkId: checkId) else {
            throw StorageError.notAuthenticated
        }

        guard let imageData = image.jpegDataResized() else {
            throw StorageError.imageConversionFailed
        }

        let ref = storage.reference().child(path)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await ref.downloadURL()
        return downloadURL.absoluteString
    }

    /// Delete a condition check photo
    func deleteConditionPhoto(towelId: String, checkId: String) async throws {
        guard let path = conditionPhotoPath(towelId: towelId, checkId: checkId) else {
            throw StorageError.notAuthenticated
        }

        let ref = storage.reference().child(path)
        try await ref.delete()
    }

    /// Delete all condition photos for a user's towels (account deletion — always personal path)
    func deleteAllUserPhotos(towels: [Towel]) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        for towel in towels {
            guard let towelId = towel.id else { continue }
            for check in towel.conditionChecks where check.photoURL != nil {
                guard let checkId = check.id else { continue }
                let path = "users/\(userId)/towels/\(towelId)/conditions/\(checkId).jpg"
                let ref = storage.reference().child(path)
                try? await ref.delete()
            }
        }
    }

    // MARK: - Photo Copy (for migration)

    /// Copy a photo from one Storage path to another, returning the new download URL
    func copyPhoto(fromPath: String, toPath: String) async throws -> String {
        let sourceRef = storage.reference().child(fromPath)
        let destRef = storage.reference().child(toPath)

        let data = try await sourceRef.data(maxSize: 10 * 1024 * 1024) // 10MB max

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await destRef.putDataAsync(data, metadata: metadata)
        let downloadURL = try await destRef.downloadURL()
        return downloadURL.absoluteString
    }

    /// Delete a photo at a specific path
    func deletePhoto(path: String) async throws {
        let ref = storage.reference().child(path)
        try await ref.delete()
    }
}

enum StorageError: LocalizedError {
    case notAuthenticated
    case imageConversionFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "サインインが必要です"
        case .imageConversionFailed:
            return "画像の変換に失敗しました"
        }
    }
}
