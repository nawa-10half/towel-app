import Foundation
import SwiftData

enum SharedModelContainer {
    static let schema = Schema([Towel.self, ExchangeRecord.self, ConditionCheck.self])

    static let shared: ModelContainer = {
        #if targetEnvironment(simulator)
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        #else
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.kaetao-app.TowelApp")
        )
        #endif

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("⚠️ CloudKit ModelContainer failed: \(error)")
            print("⚠️ Falling back to local-only database")
            let fallback = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
    }()
}
