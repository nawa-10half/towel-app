import AppIntents
import SwiftData

struct ListOverdueTowelsIntent: AppIntent {
    static var title: LocalizedStringResource = "交換が必要なタオルを確認"
    static var description: IntentDescription = "交換時期が近い、または超過しているタオルを一覧表示します"
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(SharedModelContainer.shared)
        let descriptor = FetchDescriptor<Towel>()
        let towels = try context.fetch(descriptor)

        let needsExchange = towels.filter { $0.status == .overdue || $0.status == .soon }

        if needsExchange.isEmpty {
            return .result(dialog: "すべてのタオルは順調です！交換が必要なものはありません。")
        }

        let lines = needsExchange.map { towel -> String in
            let emoji = towel.status == .overdue ? "🔴" : "🟡"
            return "\(emoji) \(towel.name)（\(towel.location)）- \(towel.status.label)・\(towel.daysSinceLastExchange)日経過"
        }

        let message = "交換が必要なタオル:\n" + lines.joined(separator: "\n")
        return .result(dialog: "\(message)")
    }
}
