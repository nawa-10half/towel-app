import Foundation
import SwiftData

@Model
final class Towel {
    @Attribute(.unique) var id: UUID
    var name: String
    var location: String
    var iconName: String
    var exchangeIntervalDays: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ExchangeRecord.towel)
    var records: [ExchangeRecord]


    @Relationship(deleteRule: .cascade, inverse: \ConditionCheck.towel)
    var conditionChecks: [ConditionCheck]

    init(
        id: UUID = UUID(),
        name: String,
        location: String,
        iconName: String = "hand.raised.fill",
        exchangeIntervalDays: Int = 3,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.iconName = iconName
        self.exchangeIntervalDays = exchangeIntervalDays
        self.createdAt = createdAt
        self.records = []
        self.conditionChecks = []
    }

    var lastExchangedAt: Date? {
        records.max(by: { $0.exchangedAt < $1.exchangedAt })?.exchangedAt
    }

    var daysSinceLastExchange: Int {
        guard let lastDate = lastExchangedAt else {
            return Calendar.current.dateComponents([.day], from: createdAt, to: .now).day ?? 0
        }
        return Calendar.current.dateComponents([.day], from: lastDate, to: .now).day ?? 0
    }

    var nextExchangeDate: Date {
        let baseDate = lastExchangedAt ?? createdAt
        return Calendar.current.date(byAdding: .day, value: exchangeIntervalDays, to: baseDate) ?? baseDate
    }

    var status: TowelStatus {
        let remaining = Calendar.current.dateComponents([.day], from: .now, to: nextExchangeDate).day ?? 0
        if remaining < 0 {
            return .overdue
        } else if remaining <= 1 {
            return .soon
        } else {
            return .ok
        }
    }

    var latestConditionCheck: ConditionCheck? {
        conditionChecks.max(by: { $0.checkedAt < $1.checkedAt })
    }
}

enum TowelStatus {
    case ok
    case soon
    case overdue

    var color: String {
        switch self {
        case .ok: return "green"
        case .soon: return "yellow"
        case .overdue: return "red"
        }
    }

    var label: String {
        switch self {
        case .ok: return "余裕あり"
        case .soon: return "もうすぐ"
        case .overdue: return "交換時期超過"
        }
    }
}
