import SwiftUI
import FirebaseCore
import GoogleMobileAds

@main
struct TowelApp: App {
    @State private var authService: AuthService
    @State private var showSplash = true
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    init() {
        FirebaseApp.configure()
        MobileAds.shared.start(completionHandler: nil)
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
            } else if showSplash {
                SplashView()
                    .task {
                        try? await Task.sleep(for: .seconds(1.2))
                        withAnimation(.easeOut(duration: 0.3)) {
                            showSplash = false
                        }
                    }
            } else if authService.isAuthenticated {
                ContentView()
                    .task {
                        _ = await NotificationService.shared.requestPermission()
                        StoreService.shared.startObserving()
                        AdService.shared.loadRewardedAd()
                    }
            } else {
                SignInView()
            }
        }
    }
}

private struct SplashView: View {
    @State private var iconScale: CGFloat = 0.6
    @State private var iconOpacity: Double = 0
    @State private var titleOpacity: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            if let icon = Bundle.main.icon {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)
            }

            Text("かえたお")
                .font(.title)
                .fontWeight(.bold)
                .opacity(titleOpacity)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5)) {
                iconScale = 1.0
                iconOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.25)) {
                titleOpacity = 1
            }
        }
    }
}

private extension Bundle {
    var icon: UIImage? {
        guard let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let name = files.last else { return nil }
        return UIImage(named: name)
    }
}
