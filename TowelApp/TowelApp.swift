import SwiftUI
import FirebaseCore
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }
}

@main
struct TowelApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var authService = AuthService.shared

    init() {
        UserDefaults.standard.register(defaults: [
            "notificationsEnabled": true,
            "notificationHour": 8,
            "notificationMinute": 0,
            "overdueNotificationEnabled": true
        ])
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isLoading {
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
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
