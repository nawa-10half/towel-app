import Foundation
import SwiftData

@Model
final class ExchangeRecord {
    var id: UUID = UUID()
    var exchangedAt: Date = Date.now
    var note: String?
    var towel: Towel?

    init(
        id: UUID = UUID(),
        exchangedAt: Date = Date.now,
        note: String? = nil,
        towel: Towel? = nil
    ) {
        self.id = id
        self.exchangedAt = exchangedAt
        self.note = note
        self.towel = towel
    }
}
