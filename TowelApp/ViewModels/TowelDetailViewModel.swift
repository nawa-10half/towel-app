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

    func deleteRecord(_ record: ExchangeRecord, context: ModelContext) {
        context.delete(record)
        do {
            try context.save()
        } catch {
            errorMessage = "交換記録の削除に失敗しました: \(error.localizedDescription)"
        }
    }
}
