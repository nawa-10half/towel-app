import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var towels: [Towel]
    @State private var towelNavigationPath = NavigationPath()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $towelNavigationPath) {
                TowelListView()
            }
            .tabItem {
                Label("タオル", systemImage: "hand.raised.fill")
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
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "towelapp",
              url.host == "towel",
              let idString = url.pathComponents.last,
              let uuid = UUID(uuidString: idString) else { return }

        guard let towel = towels.first(where: { $0.id == uuid }) else { return }

        selectedTab = 0
        towelNavigationPath = NavigationPath()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            towelNavigationPath.append(towel)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Towel.self, ExchangeRecord.self, ConditionCheck.self], inMemory: true)
}
