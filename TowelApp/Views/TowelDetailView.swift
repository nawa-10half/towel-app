import SwiftUI
import SwiftData

struct TowelDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let towel: Towel
    @State private var viewModel: TowelDetailViewModel
    @State private var showingEditForm = false
    @State private var showingExchangeSheet = false

    init(towel: Towel) {
        self.towel = towel
        self._viewModel = State(initialValue: TowelDetailViewModel(towel: towel))
    }

    var body: some View {
        List {
            statusSection
            actionSection
            historySection
        }
        .navigationTitle(towel.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("編集") {
                    showingEditForm = true
                }
            }
        }
        .sheet(isPresented: $showingEditForm) {
            TowelFormView(towel: towel)
        }
        .sheet(isPresented: $showingExchangeSheet) {
            ExchangeRecordSheet(towel: towel)
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

    private var statusSection: some View {
        Section {
            HStack {
                Label(towel.location, systemImage: "mappin")
                Spacer()
                Text("設置場所")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("\(towel.exchangeIntervalDays)日ごと", systemImage: "calendar")
                Spacer()
                Text("交換間隔")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("\(towel.daysSinceLastExchange)日経過", systemImage: "clock")
                Spacer()
                statusBadge
            }

            if let lastDate = towel.lastExchangedAt {
                HStack {
                    Label(lastDate.formatted日本語, systemImage: "arrow.counterclockwise")
                    Spacer()
                    Text("最終交換")
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Label(towel.nextExchangeDate.formattedDateOnly, systemImage: "arrow.forward")
                Spacer()
                Text("次回交換")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("ステータス")
        }
    }

    private var actionSection: some View {
        Section {
            Button {
                showingExchangeSheet = true
            } label: {
                Text("交換した！")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    private var historySection: some View {
        Section {
            if viewModel.sortedRecords.isEmpty {
                Text("交換履歴がありません")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.sortedRecords) { record in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.exchangedAt.formatted日本語)
                            .font(.subheadline)
                        if let note = record.note, !note.isEmpty {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { indexSet in
                    let records = viewModel.sortedRecords
                    for index in indexSet {
                        viewModel.deleteRecord(records[index], context: modelContext)
                    }
                }
            }
        } header: {
            Text("交換履歴")
        }
    }

    private var statusBadge: some View {
        Text(towel.status.label)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch towel.status {
        case .ok: return .green
        case .soon: return .orange
        case .overdue: return .red
        }
    }
}

// MARK: - Exchange Record Sheet

struct ExchangeRecordSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let towel: Towel
    @State private var exchangeDate = Date.now
    @State private var exchangeNote = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "交換日時",
                        selection: $exchangeDate,
                        in: ...Date.now,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                } header: {
                    Text("いつ交換しましたか？")
                }

                Section {
                    TextField("メモ（任意）", text: $exchangeNote)
                }
            }
            .navigationTitle("交換記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("記録する") {
                        let record = ExchangeRecord(
                            exchangedAt: exchangeDate,
                            note: exchangeNote.isEmpty ? nil : exchangeNote,
                            towel: towel
                        )
                        modelContext.insert(record)
                        try? modelContext.save()
                        NotificationService.shared.rescheduleNotification(for: towel)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    let towel = Towel(name: "バスタオル", location: "浴室", iconName: "shower.fill", exchangeIntervalDays: 3)
    return NavigationStack {
        TowelDetailView(towel: towel)
    }
    .modelContainer(for: [Towel.self, ExchangeRecord.self], inMemory: true)
}
