import SwiftUI

struct SettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("notificationHour") private var notificationHour = 8
    @AppStorage("notificationMinute") private var notificationMinute = 0
    @AppStorage("overdueNotificationEnabled") private var overdueNotificationEnabled = true
    @State private var firestoreService = FirestoreService.shared
    @State private var authService = AuthService.shared
    @State private var notificationPermissionDenied = false
    @State private var showingJoinSheet = false
    @State private var showingSignOutConfirmation = false
    @State private var showingDeleteAccountConfirmation = false
    @State private var pendingSignOut = false
    @State private var pendingDeleteAccount = false
    @State private var editingDisplayName: String = ""
    @State private var codeCopied = false

    private var notificationTime: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = notificationHour
                components.minute = notificationMinute
                return Calendar.current.date(from: components) ?? .now
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                notificationHour = components.hour ?? 8
                notificationMinute = components.minute ?? 0
                NotificationService.shared.rescheduleAllNotifications(for: firestoreService.towels)
            }
        )
    }

    var body: some View {
        Form {
            accountSection
            GroupSettingsView(onJoinGroupTapped: { showingJoinSheet = true })
            notificationSection
            aboutSection
            dangerSection
        }
        .navigationTitle("設定")
        .sheet(isPresented: $showingJoinSheet) {
            JoinGroupView()
        }
        .alert("通知が許可されていません", isPresented: $notificationPermissionDenied) {
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("キャンセル", role: .cancel) {
                notificationsEnabled = false
            }
        } message: {
            Text("設定アプリから通知を許可してください")
        }
        .confirmationDialog("サインアウトしますか？", isPresented: $showingSignOutConfirmation, titleVisibility: .visible) {
            Button("サインアウト", role: .destructive) {
                pendingSignOut = true
            }
        }
        // ダイアログが完全に閉じた後に実行（閉じる途中での状態変化を避ける）
        .onChange(of: showingSignOutConfirmation) { _, isShowing in
            guard !isShowing, pendingSignOut else { return }
            pendingSignOut = false
            authService.signOut()
        }
        .onChange(of: showingDeleteAccountConfirmation) { _, isShowing in
            guard !isShowing, pendingDeleteAccount else { return }
            pendingDeleteAccount = false
            Task { await authService.deleteAccount() }
        }
        .task {
            editingDisplayName = authService.displayName
        }
        .onChange(of: authService.displayName) { _, newValue in
            editingDisplayName = newValue
        }
    }

    private var accountSection: some View {
        Section {
            // 表示名編集
            HStack {
                TextField("表示名", text: $editingDisplayName)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { Task { await saveDisplayName() } }

                if editingDisplayName.trimmingCharacters(in: .whitespacesAndNewlines) != authService.displayName {
                    Button("保存") {
                        Task { await saveDisplayName() }
                    }
                    .font(.callout)
                }
            }

            // リストアコード
            if let code = authService.restoreCode {
                Button {
                    UIPasteboard.general.string = code
                    codeCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        codeCopied = false
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("リストアコード")
                                .foregroundStyle(.primary)
                            Text(code)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: codeCopied ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(.tint)
                    }
                }
            }

            Button {
                showingSignOutConfirmation = true
            } label: {
                Label("サインアウト", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } header: {
            Text("アカウント")
        }
    }

    private var notificationSection: some View {
        Section {
            Toggle("リマインダー通知", isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled) { _, newValue in
                    if newValue {
                        Task {
                            let granted = await NotificationService.shared.requestPermission()
                            if granted {
                                NotificationService.shared.rescheduleAllNotifications(for: firestoreService.towels)
                            } else {
                                await MainActor.run {
                                    notificationPermissionDenied = true
                                }
                            }
                        }
                    } else {
                        NotificationService.shared.cancelAllNotifications()
                    }
                }

            if notificationsEnabled {
                DatePicker(
                    "通知時刻",
                    selection: notificationTime,
                    displayedComponents: .hourAndMinute
                )

                Toggle("期限切れリマインド", isOn: $overdueNotificationEnabled)
                    .onChange(of: overdueNotificationEnabled) { _, _ in
                        NotificationService.shared.rescheduleAllNotifications(for: firestoreService.towels)
                    }
            }
        } header: {
            Text("通知")
        } footer: {
            if notificationsEnabled {
                Text("交換期限を過ぎたタオルについてもリマインドします")
            } else {
                Text("交換時期が近づくとリマインダーが届きます")
            }
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("バージョン")
                Spacer()
                Text("1.0")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("アプリ情報")
        }
    }

    private var dangerSection: some View {
        Section {
            if authService.isDeletingAccount {
                HStack {
                    ProgressView()
                    Text("アカウントを削除中...")
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                }
            } else {
                Button(role: .destructive) {
                    showingDeleteAccountConfirmation = true
                } label: {
                    Label("アカウント削除", systemImage: "trash")
                        .foregroundStyle(.red)
                }
                .disabled(authService.isDeletingAccount)
            }
        }
        .confirmationDialog(
            "アカウントを削除しますか？",
            isPresented: $showingDeleteAccountConfirmation,
            titleVisibility: .visible
        ) {
            Button("アカウントを削除", role: .destructive) {
                pendingDeleteAccount = true
            }
        } message: {
            Text("この操作は取り消せません。すべてのデータが削除されます。")
        }
    }

    private func saveDisplayName() async {
        do {
            try await authService.updateDisplayName(editingDisplayName)
        } catch {
            // エラーは無視（後でアラート追加も可）
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
