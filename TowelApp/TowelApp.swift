import SwiftUI
import SwiftData

@main
struct TowelApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([Towel.self, ExchangeRecord.self])
            #if targetEnvironment(simulator)
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            #else
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            #endif
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
