import Foundation
import FirebaseAuth
import FirebaseStorage
import UIKit

final class StorageService: Sendable {
    static let shared = StorageService()

    private let storage = Storage.storage()

    private init() {}

    /// Upload a condition check photo and return the download URL
    func uploadConditionPhoto(
        towelId: String,
        checkId: String,
        image: UIImage
    ) async throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw StorageError.notAuthenticated
        }

        guard let imageData = image.jpegDataResized() else {
            throw StorageError.imageConversionFailed
        }

        let path = "users/\(userId)/towels/\(towelId)/conditions/\(checkId).jpg"
        let ref = storage.reference().child(path)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await ref.downloadURL()
        return downloadURL.absoluteString
    }

    /// Delete a condition check photo
    func deleteConditionPhoto(towelId: String, checkId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw StorageError.notAuthenticated
        }

        let path = "users/\(userId)/towels/\(towelId)/conditions/\(checkId).jpg"
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
