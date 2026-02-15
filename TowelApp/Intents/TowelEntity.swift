import AppIntents
import SwiftData

struct TowelEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "タオル"
    static var defaultQuery = TowelEntityQuery()

    var id: UUID
    var name: String
    var location: String
    var daysSinceLastExchange: Int
    var statusLabel: String
    var exchangeIntervalDays: Int
    var nextExchangeDateDescription: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(location)")
    }

    init(from towel: Towel) {
        self.id = towel.id
        self.name = towel.name
        self.location = towel.location
        self.daysSinceLastExchange = towel.daysSinceLastExchange
        self.statusLabel = towel.status.label
        self.exchangeIntervalDays = towel.exchangeIntervalDays
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "ja_JP")
        self.nextExchangeDateDescription = formatter.string(from: towel.nextExchangeDate)
    }
}

struct TowelEntityQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [TowelEntity] {
        let context = ModelContext(SharedModelContainer.shared)
        let descriptor = FetchDescriptor<Towel>()
        let towels = try context.fetch(descriptor)
        return towels
            .filter { identifiers.contains($0.id) }
            .map { TowelEntity(from: $0) }
    }

    func entities(matching string: String) async throws -> [TowelEntity] {
        let context = ModelContext(SharedModelContainer.shared)
        let descriptor = FetchDescriptor<Towel>()
        let towels = try context.fetch(descriptor)
        let lowered = string.lowercased()
        return towels
            .filter { $0.name.lowercased().contains(lowered) || $0.location.lowercased().contains(lowered) }
            .map { TowelEntity(from: $0) }
    }

    func suggestedEntities() async throws -> [TowelEntity] {
        let context = ModelContext(SharedModelContainer.shared)
        let descriptor = FetchDescriptor<Towel>()
        let towels = try context.fetch(descriptor)
        return towels.map { TowelEntity(from: $0) }
    }
}
