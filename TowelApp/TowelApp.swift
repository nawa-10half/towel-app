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

        modelContainer = SharedModelContainer.shared
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
