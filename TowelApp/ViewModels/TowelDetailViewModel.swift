import Foundation
import SwiftData
import Observation
import WidgetKit

@Observable
final class TowelDetailViewModel {
    let towel: Towel
    var errorMessage: String?
    var isAssessing = false

    init(towel: Towel) {
        self.towel = towel
    }

    var sortedRecords: [ExchangeRecord] {
        (towel.records ?? []).sorted { $0.exchangedAt > $1.exchangedAt }
    }

    var sortedConditionChecks: [ConditionCheck] {
        (towel.conditionChecks ?? []).sorted { $0.checkedAt > $1.checkedAt }
    }

    func deleteRecord(_ record: ExchangeRecord, context: ModelContext) {
        context.delete(record)
        do {
            try context.save()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            errorMessage = "交換記録の削除に失敗しました: \(error.localizedDescription)"
        }
    }

    func assessCondition(imageData: Data, context: ModelContext) async {
        isAssessing = true
        defer { isAssessing = false }

        do {
            let result = try await ConditionCheckService.shared.assessCondition(
                imageData: imageData,
                towelName: towel.name,
                towelLocation: towel.location
            )

            let check = ConditionCheck(
                photoData: imageData,
                overallScore: result.overallScore,
                colorFadingScore: result.colorFadingScore,
                stainScore: result.stainScore,
                fluffinessScore: result.fluffinessScore,
                frayingScore: result.frayingScore,
                comment: result.comment,
                recommendation: result.recommendation,
                towel: towel
            )
            context.insert(check)
            try context.save()
        } catch {
            errorMessage = "状態診断に失敗しました: \(error.localizedDescription)"
        }
    }

    func deleteConditionCheck(_ check: ConditionCheck, context: ModelContext) {
        context.delete(check)
        do {
            try context.save()
        } catch {
            errorMessage = "診断記録の削除に失敗しました: \(error.localizedDescription)"
        }
    }
}
