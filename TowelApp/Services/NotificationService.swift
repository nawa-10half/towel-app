import Foundation
import UserNotifications

final class NotificationService: @unchecked Sendable {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()
    private let overduePrefs = UserDefaults.standard
    private let overdueKeyPrefix = "overdueNotified_"

    private init() {}

    private func isOverdueAlreadyNotified(towelId: String, exchangeDateKey: TimeInterval) -> Bool {
        overduePrefs.double(forKey: "\(overdueKeyPrefix)\(towelId)") == exchangeDateKey
    }

    private func markOverdueNotified(towelId: String, exchangeDateKey: TimeInterval) {
        overduePrefs.set(exchangeDateKey, forKey: "\(overdueKeyPrefix)\(towelId)")
    }

    private func clearOverdueTracking(towelId: String) {
        overduePrefs.removeObject(forKey: "\(overdueKeyPrefix)\(towelId)")
    }

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func scheduleNotification(for towel: Towel) {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }
        guard let towelId = towel.id else { return }

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
                let exchangeDateKey = scheduledDate.timeIntervalSince1970
                guard !self.isOverdueAlreadyNotified(towelId: towelId, exchangeDateKey: exchangeDateKey) else { return }
                self.markOverdueNotified(towelId: towelId, exchangeDateKey: exchangeDateKey)
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            } else {
                self.clearOverdueTracking(towelId: towelId)
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
