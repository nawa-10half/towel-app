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

    func scheduleNotification(for towel: Towel) {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }

        center.getNotificationSettings { [weak self] settings in
            guard let self, settings.authorizationStatus == .authorized else { return }

            let content = UNMutableNotificationContent()
            content.title = "タオル交換のお知らせ"
            content.body = "\(towel.name)（\(towel.location)）の交換時期です"
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
                guard UserDefaults.standard.bool(forKey: "overdueNotificationEnabled") else { return }
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            } else {
                trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            }

            let request = UNNotificationRequest(
                identifier: "towel-\(towel.id.uuidString)",
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
        center.removePendingNotificationRequests(
            withIdentifiers: ["towel-\(towel.id.uuidString)"]
        )
    }

    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }
}
