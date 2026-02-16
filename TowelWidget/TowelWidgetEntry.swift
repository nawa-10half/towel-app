import WidgetKit

struct TowelSnapshot: Identifiable {
    let id: String
    let name: String
    let location: String
    let iconName: String
    let daysSinceLastExchange: Int
    let exchangeIntervalDays: Int
    let status: WidgetTowelStatus
}

enum WidgetTowelStatus {
    case ok
    case soon
    case overdue

    var label: String {
        switch self {
        case .ok: return "余裕あり"
        case .soon: return "もうすぐ"
        case .overdue: return "交換時期超過"
        }
    }

    var sortOrder: Int {
        switch self {
        case .overdue: return 0
        case .soon: return 1
        case .ok: return 2
        }
    }
}

struct TowelWidgetEntry: TimelineEntry {
    let date: Date
    let towels: [TowelSnapshot]

    static let placeholder = TowelWidgetEntry(
        date: .now,
        towels: [
            TowelSnapshot(
                id: "preview-1",
                name: "バスタオル",
                location: "浴室",
                iconName: "shower.fill",
                daysSinceLastExchange: 5,
                exchangeIntervalDays: 3,
                status: .overdue
            ),
            TowelSnapshot(
                id: "preview-2",
                name: "フェイスタオル",
                location: "洗面所",
                iconName: "face.smiling",
                daysSinceLastExchange: 2,
                exchangeIntervalDays: 3,
                status: .soon
            ),
            TowelSnapshot(
                id: "preview-3",
                name: "キッチンタオル",
                location: "キッチン",
                iconName: "fork.knife",
                daysSinceLastExchange: 1,
                exchangeIntervalDays: 5,
                status: .ok
            ),
            TowelSnapshot(
                id: "preview-4",
                name: "トイレタオル",
                location: "トイレ",
                iconName: "toilet.fill",
                daysSinceLastExchange: 0,
                exchangeIntervalDays: 3,
                status: .ok
            ),
        ]
    )
}
