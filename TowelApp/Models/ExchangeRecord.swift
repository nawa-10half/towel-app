import Foundation
import SwiftData

@Model
final class ExchangeRecord {
    @Attribute(.unique) var id: UUID
    var exchangedAt: Date
    var note: String?
    var towel: Towel?

    init(
        id: UUID = UUID(),
        exchangedAt: Date = .now,
        note: String? = nil,
        towel: Towel? = nil
    ) {
        self.id = id
        self.exchangedAt = exchangedAt
        self.note = note
        self.towel = towel
    }
}
