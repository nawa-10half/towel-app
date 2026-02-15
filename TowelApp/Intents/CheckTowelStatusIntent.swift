import AppIntents
import SwiftData

struct CheckTowelStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "タオルの状態を確認"
    static var description: IntentDescription = "指定したタオルの交換状態を確認します"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "タオル")
    var towel: TowelEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(SharedModelContainer.shared)
        let towelId = towel.id
        var descriptor = FetchDescriptor<Towel>(
            predicate: #Predicate { $0.id == towelId }
        )
        descriptor.fetchLimit = 1

        guard let foundTowel = try context.fetch(descriptor).first else {
            throw IntentError.towelNotFound
        }

        let days = foundTowel.daysSinceLastExchange
        let status = foundTowel.status.label
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "ja_JP")
        let nextDate = formatter.string(from: foundTowel.nextExchangeDate)

        let message = """
        \(foundTowel.name)（\(foundTowel.location)）
        状態: \(status)
        前回交換から: \(days)日経過
        次回交換予定: \(nextDate)
        """

        return .result(dialog: "\(message)")
    }
}
