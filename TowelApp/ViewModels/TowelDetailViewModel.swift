import Foundation
import SwiftData
import Observation

@Observable
final class TowelDetailViewModel {
    let towel: Towel
    var errorMessage: String?

    init(towel: Towel) {
        self.towel = towel
    }

    var sortedRecords: [ExchangeRecord] {
        towel.records.sorted { $0.exchangedAt > $1.exchangedAt }
    }

    func exchangeNow(at date: Date = .now, note: String? = nil, context: ModelContext) {
        let record = ExchangeRecord(exchangedAt: date, note: note, towel: towel)
        context.insert(record)
        do {
            try context.save()
            NotificationService.shared.rescheduleNotification(for: towel)
        } catch {
            errorMessage = "交換記録の保存に失敗しました: \(error.localizedDescription)"
        }
    }

    func deleteRecord(_ record: ExchangeRecord, context: ModelContext) {
        context.delete(record)
        do {
            try context.save()
        } catch {
            errorMessage = "交換記録の削除に失敗しました: \(error.localizedDescription)"
        }
    }
}
