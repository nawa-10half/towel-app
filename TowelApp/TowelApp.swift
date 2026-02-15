import SwiftUI
import SwiftData

@main
struct TowelApp: App {
    let modelContainer: ModelContainer

    init() {
        UserDefaults.standard.register(defaults: [
            "notificationsEnabled": true,
            "notificationHour": 8,
            "notificationMinute": 0,
            "overdueNotificationEnabled": true
        ])

        do {
            let schema = Schema([Towel.self, ExchangeRecord.self, ConditionCheck.self])
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
                .task {
                    _ = await NotificationService.shared.requestPermission()
                }
        }
        .modelContainer(modelContainer)
    }
}
