import SwiftUI

struct UserProfileEditView: View {
    @State private var authService = AuthService.shared
    @State private var displayName: String = ""
    @State private var iconName: String = UserProfile.defaultIconName
    @State private var iconColor: String = UserProfile.defaultIconColor
    @State private var isSaving = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private let iconColumns = [GridItem(.adaptive(minimum: 56), spacing: 12)]
    private let colorColumns = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        UserProfileIconView(iconName: iconName, colorName: iconColor, size: 88)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("表示名") {
                    TextField("表示名", text: $displayName)
                        .autocorrectionDisabled()
                }

                Section("アイコン") {
                    LazyVGrid(columns: iconColumns, spacing: 12) {
                        ForEach(UserProfileIconPalette.icons, id: \.self) { name in
                            Button {
                                iconName = name
                            } label: {
                                Image(systemName: name)
                                    .font(.system(size: 22))
                                    .frame(width: 48, height: 48)
                                    .background(
                                        Circle()
                                            .fill(iconName == name ? UserProfileIconPalette.color(for: iconColor).opacity(0.2) : Color.gray.opacity(0.12))
                                    )
                                    .overlay(
                                        Circle()
                                            .strokeBorder(iconName == name ? UserProfileIconPalette.color(for: iconColor) : .clear, lineWidth: 2)
                                    )
                                    .foregroundStyle(iconName == name ? UserProfileIconPalette.color(for: iconColor) : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("カラー") {
                    LazyVGrid(columns: colorColumns, spacing: 12) {
                        ForEach(UserProfileIconPalette.colors, id: \.name) { entry in
                            Button {
                                iconColor = entry.name
                            } label: {
                                Circle()
                                    .fill(entry.color)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(.primary, lineWidth: iconColor == entry.name ? 3 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("プロフィール編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
            .alert("エラー", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear {
                displayName = authService.displayName
                iconName = authService.iconName
                iconColor = authService.iconColor
            }
        }
    }

    private func save() async {
        guard NetworkMonitor.shared.isConnected else {
            errorMessage = String(localized: "オフラインのためプロフィールを変更できません。ネットワーク接続後に再度お試しください。")
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await authService.updateProfile(iconName: iconName, iconColor: iconColor)
            let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed != authService.displayName {
                try await authService.updateDisplayName(trimmed)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct UserProfileIconView: View {
    let iconName: String
    let colorName: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(UserProfileIconPalette.color(for: colorName).opacity(0.2))
                .frame(width: size, height: size)
            Image(systemName: iconName)
                .font(.system(size: size * 0.45))
                .foregroundStyle(UserProfileIconPalette.color(for: colorName))
        }
    }
}
