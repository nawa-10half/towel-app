import SwiftUI

struct ContentView: View {
    @State private var firestoreService = FirestoreService.shared
    @State private var towelNavigationPath = NavigationPath()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $towelNavigationPath) {
                TowelListView()
            }
            .tabItem {
                Label("アイテム", systemImage: "hand.raised.fill")
            }
            .tag(0)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("設定", systemImage: "gearshape")
            }
            .tag(1)
        }
        .task {
            await GroupService.shared.loadGroupForCurrentUser()
            firestoreService.startListening()
        }
        .onChange(of: firestoreService.towels) { _, towels in
            NotificationService.shared.rescheduleAllNotifications(for: towels)
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "towelapp",
              url.host == "towel",
              let idString = url.pathComponents.last else { return }

        guard let towel = firestoreService.towels.first(where: { $0.id == idString }) else { return }

        selectedTab = 0
        towelNavigationPath = NavigationPath()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            towelNavigationPath.append(towel)
        }
    }
}

#Preview {
    ContentView()
}
