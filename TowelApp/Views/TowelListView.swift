import SwiftUI

struct TowelListView: View {
    @State private var firestoreService = FirestoreService.shared
    @State private var viewModel = TowelListViewModel()
    @State private var networkMonitor = NetworkMonitor.shared
    @State private var showingAddForm = false
    @State private var towelToExchange: Towel?
    @State private var towelToDelete: Towel?
    @State private var deleteTrigger = false

    var body: some View {
        VStack(spacing: 0) {
            if !networkMonitor.isConnected {
                HStack(spacing: 6) {
                    Image(systemName: "wifi.slash")
                        .font(.caption)
                    Text("オフライン — 接続復旧後に同期されます")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(.orange.opacity(0.15))
                .foregroundStyle(.orange)
            }

            Group {
                if firestoreService.isLoading {
                    ProgressView()
                } else if firestoreService.towels.isEmpty {
                    emptyStateView
                } else {
                    towelList
                }
            }
        }
        .navigationTitle("タオリスト")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "タオルを検索")
        .sheet(isPresented: $showingAddForm) {
            TowelFormView()
        }
        .alert("エラー", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("タオルがありません", systemImage: "hand.raised.fill")
        } description: {
            Text("右上の＋ボタンからタオルを追加しましょう")
        } actions: {
            Button("タオルを追加") {
                showingAddForm = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var towelList: some View {
        List {
            let filtered = viewModel.filteredTowels(firestoreService.towels)
            let sorted = viewModel.sortedByStatus(filtered)
            ForEach(sorted) { towel in
                NavigationLink(value: towel) {
                    TowelRowView(towel: towel)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        towelToExchange = towel
                    } label: {
                        Text("交換した！")
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        towelToDelete = towel
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }
        }
        .navigationDestination(for: Towel.self) { towel in
            if let towelId = towel.id {
                TowelDetailView(towelId: towelId)
            }
        }
        .sheet(item: $towelToExchange) { towel in
            if let towelId = towel.id {
                ExchangeRecordSheet(towelId: towelId, towelName: towel.name)
            }
        }
        .confirmationDialog(
            "「\(towelToDelete?.name ?? "")」を削除しますか？",
            isPresented: Binding(
                get: { towelToDelete != nil },
                set: { if !$0 { towelToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                if let towel = towelToDelete {
                    viewModel.deleteTowel(towel)
                    towelToDelete = nil
                    deleteTrigger.toggle()
                }
            }
        } message: {
            Text("交換履歴と診断履歴もすべて削除されます。この操作は取り消せません。")
        }
        .sensoryFeedback(.warning, trigger: deleteTrigger)
        .refreshable {
            firestoreService.stopListening()
            firestoreService.startListening()
            try? await Task.sleep(for: .seconds(1))
        }
    }
}

#Preview {
    NavigationStack {
        TowelListView()
    }
}
