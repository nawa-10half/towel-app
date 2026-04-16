import Foundation
import FirebaseFirestore

struct ExchangeRecord: Codable, Identifiable {
    @DocumentID var id: String?
    @ServerTimestamp var exchangedAt: Date?
    var note: String?
    var createdBy: String?
    @ServerTimestamp var createdAt: Date?
}
