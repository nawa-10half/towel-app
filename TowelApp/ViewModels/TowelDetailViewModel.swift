import Foundation
import SwiftData
import Observation

@Observable
final class TowelDetailViewModel {
    let towel: Towel

    init(towel: Towel) {
        self.towel = towel
    }

    var sortedRecords: [ExchangeRecord] {
        towel.records.sorted { $0.exchangedAt > $1.exchangedAt }
    }

    func exchangeNow(note: String? = nil, context: ModelContext) {
        let record = ExchangeRecord(exchangedAt: .now, note: note, towel: towel)
        context.insert(record)
        NotificationService.shared.rescheduleNotification(for: towel)
    }

    func deleteRecord(_ record: ExchangeRecord, context: ModelContext) {
        context.delete(record)
    }
}
