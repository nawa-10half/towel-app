import AppIntents
import SwiftData

struct RecordExchangeIntent: AppIntent {
    static var title: LocalizedStringResource = "タオルの交換を記録"
    static var description: IntentDescription = "指定したタオルの交換を記録します"
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

        let record = ExchangeRecord(towel: foundTowel)
        context.insert(record)
        try context.save()

        NotificationService.shared.rescheduleNotification(for: foundTowel)

        return .result(dialog: "\(foundTowel.name)の交換を記録しました")
    }
}
