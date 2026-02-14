import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                TowelListView()
            }
            .tabItem {
                Label("タオル", systemImage: "hand.raised.fill")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("設定", systemImage: "gearshape")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Towel.self, ExchangeRecord.self], inMemory: true)
}
