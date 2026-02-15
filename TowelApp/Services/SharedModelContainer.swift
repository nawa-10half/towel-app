import SwiftData

enum SharedModelContainer {
    static let shared: ModelContainer = {
        do {
            let schema = Schema([Towel.self, ExchangeRecord.self, ConditionCheck.self])
            #if targetEnvironment(simulator)
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            #else
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            #endif
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
}
