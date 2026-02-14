import SwiftUI
import SwiftData

struct TowelListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Towel.createdAt, order: .reverse) private var towels: [Towel]
    @State private var viewModel = TowelListViewModel()
    @State private var showingAddForm = false

    var body: some View {
        Group {
            if towels.isEmpty {
                emptyStateView
            } else {
                towelList
            }
        }
        .navigationTitle("タオル")
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
            let filtered = viewModel.filteredTowels(towels)
            let sorted = viewModel.sortedByStatus(filtered)
            ForEach(sorted) { towel in
                NavigationLink(value: towel) {
                    TowelRowView(towel: towel)
                }
            }
            .onDelete { indexSet in
                let sorted = viewModel.sortedByStatus(viewModel.filteredTowels(towels))
                for index in indexSet {
                    viewModel.deleteTowel(sorted[index], context: modelContext)
                }
            }
        }
        .navigationDestination(for: Towel.self) { towel in
            TowelDetailView(towel: towel)
        }
    }
}

#Preview {
    NavigationStack {
        TowelListView()
    }
    .modelContainer(for: [Towel.self, ExchangeRecord.self], inMemory: true)
}
