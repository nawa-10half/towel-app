import SwiftUI
import FirebaseCore

@main
struct TowelApp: App {
    @State private var authService: AuthService
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    init() {
        FirebaseApp.configure()
        _authService = State(initialValue: AuthService.shared)
        UserDefaults.standard.register(defaults: [
            "notificationsEnabled": true,
            "notificationHour": 8,
            "notificationMinute": 0,
            "overdueNotificationEnabled": true
        ])
    }

    var body: some Scene {
        WindowGroup {
            if !hasSeenOnboarding {
                OnboardingView()
            } else if authService.isLoading {
                ProgressView()
            } else if authService.isAuthenticated {
                ContentView()
                    .task {
                        _ = await NotificationService.shared.requestPermission()
                    }
            } else {
                SignInView()
            }
        }
    }
}
