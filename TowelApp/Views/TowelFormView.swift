import SwiftUI
import SwiftData

struct TowelFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let towel: Towel?

    @State private var name: String
    @State private var location: String
    @State private var iconName: String
    @State private var exchangeIntervalDays: Int
    @State private var showingIconPicker = false
    @State private var errorMessage: String?

    private var isEditing: Bool { towel != nil }

    private static let availableIcons = [
        "hand.raised.fill",
        "shower.fill",
        "sink.fill",
        "bathtub.fill",
        "face.smiling",
        "fork.knife",
        "cup.and.saucer.fill",
        "washer.fill",
        "bed.double.fill",
        "toilet.fill",
        "figure.run",
        "dumbbell.fill"
    ]

    private static let locationSuggestions = [
        "浴室", "キッチン", "トイレ", "洗面所", "リビング", "寝室", "ジム"
    ]

    init(towel: Towel? = nil) {
        self.towel = towel
        self._name = State(initialValue: towel?.name ?? "")
        self._location = State(initialValue: towel?.location ?? "")
        self._iconName = State(initialValue: towel?.iconName ?? "hand.raised.fill")
        self._exchangeIntervalDays = State(initialValue: towel?.exchangeIntervalDays ?? 3)
    }

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                locationSection
                iconSection
                intervalSection
            }
            .navigationTitle(isEditing ? "タオルを編集" : "タオルを追加")
            .navigationBarTitleDisplayMode(.inline)
            .alert("エラー", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "保存" : "追加") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty ||
                              location.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var nameSection: some View {
        Section {
            TextField("タオルの名前", text: $name)
        } header: {
            Text("名前")
        }
    }

    private var locationSection: some View {
        Section {
            TextField("設置場所", text: $location)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.locationSuggestions, id: \.self) { suggestion in
                        Button(suggestion) {
                            location = suggestion
                        }
                        .buttonStyle(.bordered)
                        .tint(location == suggestion ? .accentColor : .secondary)
                    }
                }
            }
        } header: {
            Text("設置場所")
        }
    }

    private var iconSection: some View {
        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(Self.availableIcons, id: \.self) { icon in
                    Button {
                        iconName = icon
                    } label: {
                        Image(systemName: icon)
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(iconName == icon ? Color.accentColor.opacity(0.2) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(iconName == icon ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("アイコン")
        }
    }

    private var intervalSection: some View {
        Section {
            Stepper("\(exchangeIntervalDays)日ごと", value: $exchangeIntervalDays, in: 1...30)
        } header: {
            Text("交換間隔")
        } footer: {
            Text("タオルの交換推奨間隔を設定します")
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)

        if let towel {
            towel.name = trimmedName
            towel.location = trimmedLocation
            towel.iconName = iconName
            towel.exchangeIntervalDays = exchangeIntervalDays
        } else {
            let newTowel = Towel(
                name: trimmedName,
                location: trimmedLocation,
                iconName: iconName,
                exchangeIntervalDays: exchangeIntervalDays
            )
            modelContext.insert(newTowel)
            NotificationService.shared.scheduleNotification(for: newTowel)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
        }
    }
}

#Preview {
    TowelFormView()
        .modelContainer(for: [Towel.self, ExchangeRecord.self, ConditionCheck.self], inMemory: true)
}
