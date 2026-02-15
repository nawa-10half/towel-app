import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("notificationHour") private var notificationHour = 8
    @AppStorage("notificationMinute") private var notificationMinute = 0
    @AppStorage("overdueNotificationEnabled") private var overdueNotificationEnabled = true
    @Query private var towels: [Towel]
    @State private var showingShareSheet = false
    @State private var notificationPermissionDenied = false

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
                NotificationService.shared.rescheduleAllNotifications(for: towels)
            }
        )
    }

    var body: some View {
        Form {
            notificationSection
            sharingSection
            aboutSection
        }
        .navigationTitle("設定")
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
    }

    private var notificationSection: some View {
        Section {
            Toggle("リマインダー通知", isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled) { _, newValue in
                    if newValue {
                        Task {
                            let granted = await NotificationService.shared.requestPermission()
                            if granted {
                                NotificationService.shared.rescheduleAllNotifications(for: towels)
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
                        NotificationService.shared.rescheduleAllNotifications(for: towels)
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

    private var sharingSection: some View {
        Section {
            Button {
                showingShareSheet = true
            } label: {
                Label("iCloudで家族と共有", systemImage: "person.2.fill")
            }
        } header: {
            Text("データ共有")
        } footer: {
            Text("iCloud経由で家族メンバーとタオルデータを共有できます")
        }
        .sheet(isPresented: $showingShareSheet) {
            CloudSharingView()
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
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
