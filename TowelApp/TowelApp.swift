import SwiftUI
import SwiftData
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
    let modelContainer: ModelContainer

    init() {
        UserDefaults.standard.register(defaults: [
            "notificationsEnabled": true,
            "notificationHour": 8,
            "notificationMinute": 0,
            "overdueNotificationEnabled": true
        ])

        Self.migrateStoreToAppGroupIfNeeded()
        modelContainer = SharedModelContainer.shared
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
        .modelContainer(modelContainer)
    }

    private static func migrateStoreToAppGroupIfNeeded() {
        #if !targetEnvironment(simulator)
        let migrationKey = "hasCompletedAppGroupMigration"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.kaetao-app.TowelApp"
        ) else { return }

        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let oldStoreURL = appSupportURL?.appendingPathComponent("default.store") else { return }

        let newStoreURL = groupURL.appendingPathComponent("default.store")

        guard fileManager.fileExists(atPath: oldStoreURL.path),
              !fileManager.fileExists(atPath: newStoreURL.path) else {
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        let suffixes = ["", "-wal", "-shm"]
        for suffix in suffixes {
            let source = URL(fileURLWithPath: oldStoreURL.path + suffix)
            let dest = URL(fileURLWithPath: newStoreURL.path + suffix)
            if fileManager.fileExists(atPath: source.path) {
                try? fileManager.copyItem(at: source, to: dest)
            }
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
        #endif
    }
}
