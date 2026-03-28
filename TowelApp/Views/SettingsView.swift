import SwiftUI
import StoreKit
import Combine

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
    @State private var editingDisplayName: String = ""
    @State private var codeCopied = false
    @State private var alexaLinkCode: String? = nil
    @State private var alexaLinkExpiry: Date? = nil
    @State private var isGeneratingAlexaCode = false
    @State private var alexaCodeCopied = false
    @State private var errorMessage: String?
    @State private var copyHapticTrigger = false
    @State private var showingPaywall = false
    @State private var showingManageSubscriptions = false
    @State private var storeService = StoreService.shared

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
            if Locale.current.language.languageCode == .japanese {
                alexaSection
            }
            subscriptionSection
            aboutSection
            dangerSection
        }
        .navigationTitle("設定")
        .sheet(isPresented: $showingJoinSheet) {
            JoinGroupView()
        }
        .sheet(isPresented: $showingPaywall) {
            ProPaywallView(feature: .assessment)
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
        .alert("エラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sensoryFeedback(.selection, trigger: copyHapticTrigger)
        .sensoryFeedback(.error, trigger: errorMessage)
        .confirmationDialog("サインアウトしますか？", isPresented: $showingSignOutConfirmation, titleVisibility: .visible) {
            Button("サインアウト", role: .destructive) {
                authService.signOut()
            }
        }
        .task {
            editingDisplayName = authService.displayName
        }
        .onChange(of: authService.displayName) { _, newValue in
            editingDisplayName = newValue
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if let expiry = alexaLinkExpiry, expiry <= .now {
                alexaLinkCode = nil
                alexaLinkExpiry = nil
            }
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
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("リストアコード")
                            .foregroundStyle(.primary)
                        Text(code)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        UIPasteboard.general.string = code
                        codeCopied = true
                        copyHapticTrigger.toggle()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            codeCopied = false
                        }
                    } label: {
                        Image(systemName: codeCopied ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.borderless)
                    ShareLink(item: restoreCodeShareText(code)) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.borderless)
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

    private var alexaSection: some View {
        Section {
            if let code = alexaLinkCode, let expiry = alexaLinkExpiry, expiry > .now {
                Button {
                    UIPasteboard.general.string = code
                    alexaCodeCopied = true
                    copyHapticTrigger.toggle()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        alexaCodeCopied = false
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("連携コード")
                                .foregroundStyle(.primary)
                            Text(code)
                                .font(.system(.title2, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundStyle(.tint)
                            Text("有効期限: あと \(expiry, style: .relative)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: alexaCodeCopied ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(.tint)
                    }
                    .padding(.vertical, 4)
                }
            }

            Button {
                Task { await generateAlexaCode() }
            } label: {
                if isGeneratingAlexaCode {
                    ProgressView()
                } else {
                    Label(
                        alexaLinkCode != nil ? "コードを再生成" : "連携コードを生成",
                        systemImage: "person.badge.key"
                    )
                }
            }
            .disabled(isGeneratingAlexaCode)
        } header: {
            Text("Alexa 連携")
        } footer: {
            Text("生成されたコードをAlexaアカウントリンクページで入力してください。コードは10分間有効です。")
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

    private var subscriptionSection: some View {
        Section {
            if storeService.isPro {
                HStack {
                    Label("Pro プラン", systemImage: "star.fill")
                        .foregroundStyle(.orange)
                    Spacer()
                    Text("有効")
                        .foregroundStyle(.secondary)
                }
                Button("サブスクリプションを管理") {
                    showingManageSubscriptions = true
                }
                .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
            } else {
                Button {
                    showingPaywall = true
                } label: {
                    HStack {
                        Label("Pro プランにアップグレード", systemImage: "star")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("サブスクリプション")
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("バージョン")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                    .foregroundStyle(.secondary)
            }
            Link(destination: URL(string: "https://kaetao-c43f1.web.app/privacy-policy")!) {
                HStack {
                    Text("プライバシーポリシー")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                }
            }
            Link(destination: URL(string: "https://kaetao-c43f1.web.app/terms-of-use")!) {
                HStack {
                    Text("利用規約")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                }
            }
            Link(destination: URL(string: "https://kaetao-c43f1.web.app/support")!) {
                HStack {
                    Text("よくある質問")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                }
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
                Task { await authService.deleteAccount() }
            }
        } message: {
            if StoreService.shared.isPro {
                Text("この操作は取り消せません。すべてのデータが削除されます。\n\nサブスクリプションをご利用の場合、アカウント削除後もApple IDへの課金は継続されます。設定アプリ → サブスクリプションから解約してください。")
            } else {
                Text("この操作は取り消せません。すべてのデータが削除されます。")
            }
        }
    }

    private func generateAlexaCode() async {
        guard NetworkMonitor.shared.isConnected else {
            errorMessage = String(localized: "オフラインのためAlexaコードを生成できません。ネットワーク接続後に再度お試しください。")
            return
        }
        isGeneratingAlexaCode = true
        defer { isGeneratingAlexaCode = false }
        do {
            let code = try await authService.generateAlexaLinkCode()
            alexaLinkCode = code
            alexaLinkExpiry = Date().addingTimeInterval(10 * 60)
        } catch {
            errorMessage = String(localized: "Alexaコードの生成に失敗しました: \(error.localizedDescription)")
        }
    }

    private func restoreCodeShareText(_ code: String) -> String {
        String(localized: "【かえたお リストアコード】\n\(code)\n\n機種変更や再インストール時に必要です。大切に保管してください。")
    }

    private func saveDisplayName() async {
        guard NetworkMonitor.shared.isConnected else {
            editingDisplayName = authService.displayName
            errorMessage = String(localized: "オフラインのため表示名を変更できません。ネットワーク接続後に再度お試しください。")
            return
        }
        do {
            try await authService.updateDisplayName(editingDisplayName)
        } catch {
            editingDisplayName = authService.displayName
            errorMessage = String(localized: "表示名の保存に失敗しました: \(error.localizedDescription)")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
