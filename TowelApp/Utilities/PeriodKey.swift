import Foundation

enum PeriodKey {
    private static let reference = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!

    static func current(now: Date = Date()) -> String {
        let days = Calendar.current.dateComponents([.day], from: reference, to: now).day ?? 0
        return "period-\(days / 3)"
    }
}
