import SwiftUI
import SwiftData

@main
struct TowelApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Towel.self, ExchangeRecord.self], isAutosaveEnabled: true)
    }
}
