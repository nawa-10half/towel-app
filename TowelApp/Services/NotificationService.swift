import Foundation
import UserNotifications

final class NotificationService: @unchecked Sendable {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    private init() {}

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    /// 次の通知時刻を返す。今日の設定時刻がまだなら今日、過ぎていれば明日。
    private func nextNotificationDateComponents() -> DateComponents {
        let hour = UserDefaults.standard.integer(forKey: "notificationHour")
        let minute = UserDefaults.standard.integer(forKey: "notificationMinute")
        return Self.nextNotificationDateComponents(hour: hour, minute: minute, now: Date.now)
    }

    static func nextNotificationDateComponents(hour: Int, minute: Int, now: Date) -> DateComponents {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute

        if let today = Calendar.current.date(from: components), today <= now {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
            components = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
            components.hour = hour
            components.minute = minute
        }
        return components
    }

    func scheduleNotification(for towel: Towel) {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }
        guard let towelId = towel.id else { return }

        center.getNotificationSettings { [weak self] settings in
            guard let self, settings.authorizationStatus == .authorized else { return }

            let content = UNMutableNotificationContent()
            content.title = String(localized: "交換のお知らせ")
            content.body = String(localized: "\(towel.name)（\(towel.location)）の交換時期です")
            content.sound = .default
            content.categoryIdentifier = "TOWEL_EXCHANGE"

            let triggerDate = towel.nextExchangeDate
            let notificationHour = UserDefaults.standard.integer(forKey: "notificationHour")
            let notificationMinute = UserDefaults.standard.integer(forKey: "notificationMinute")

            var components = Calendar.current.dateComponents([.year, .month, .day], from: triggerDate)
            components.hour = notificationHour
            components.minute = notificationMinute

            let scheduledDate = Calendar.current.date(from: components) ?? triggerDate

            let trigger: UNNotificationTrigger
            if scheduledDate <= Date.now {
                // 期限切れ: 次の通知時刻（今日 or 明日）にスケジュール
                guard UserDefaults.standard.bool(forKey: "overdueNotificationEnabled") else { return }
                let nextComponents = self.nextNotificationDateComponents()
                trigger = UNCalendarNotificationTrigger(dateMatching: nextComponents, repeats: false)
            } else {
                trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            }

            let request = UNNotificationRequest(
                identifier: "towel-\(towelId)",
                content: content,
                trigger: trigger
            )

            self.center.add(request)
        }
    }

    func rescheduleNotification(for towel: Towel) {
        cancelNotification(for: towel)
        scheduleNotification(for: towel)
    }

    func rescheduleAllNotifications(for towels: [Towel]) {
        cancelAllNotifications()
        for towel in towels {
            scheduleNotification(for: towel)
        }
    }

    func cancelNotification(for towel: Towel) {
        guard let towelId = towel.id else { return }
        center.removePendingNotificationRequests(
            withIdentifiers: ["towel-\(towelId)"]
        )
    }

    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }
}
