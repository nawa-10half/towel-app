import Foundation
import SwiftData

enum SharedModelContainer {
    static let schema = Schema([Towel.self, ExchangeRecord.self, ConditionCheck.self])

    static let shared: ModelContainer = {
        do {
            let config: ModelConfiguration
            #if targetEnvironment(simulator)
            config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            #else
            if let groupURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.com.kaetao.TowelApp"
            ) {
                let storeURL = groupURL.appendingPathComponent("default.store")
                config = ModelConfiguration(
                    schema: schema,
                    url: storeURL,
                    cloudKitDatabase: .automatic
                )
            } else {
                config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            }
            #endif
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
}
