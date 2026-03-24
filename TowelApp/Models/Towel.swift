import Foundation
import FirebaseFirestore

struct Towel: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var name: String = ""
    var location: String = ""
    var iconName: String = "hand.raised.fill"
    var exchangeIntervalDays: Int = 3
    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var updatedAt: Date?
    var lastExchangedAt: Date?

    // Not stored in Firestore — populated from subcollections
    var records: [ExchangeRecord] = []
    var conditionChecks: [ConditionCheck] = []

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case location
        case iconName
        case exchangeIntervalDays
        case createdAt
        case updatedAt
        case lastExchangedAt
    }

    var daysSinceLastExchange: Int {
        guard let lastDate = lastExchangedAt else {
            return Calendar.current.dateComponents([.day], from: createdAt ?? .now, to: .now).day ?? 0
        }
        return Calendar.current.dateComponents([.day], from: lastDate, to: .now).day ?? 0
    }

    var nextExchangeDate: Date {
        let baseDate = lastExchangedAt ?? createdAt ?? .now
        return Calendar.current.date(byAdding: .day, value: exchangeIntervalDays, to: baseDate) ?? baseDate
    }

    var status: TowelStatus {
        let remainingSeconds = nextExchangeDate.timeIntervalSinceNow
        let totalSeconds = Double(exchangeIntervalDays) * 86400
        if remainingSeconds < 0 {
            return .overdue
        } else if remainingSeconds < totalSeconds * 0.3 {
            return .soon
        } else {
            return .ok
        }
    }

    var latestConditionCheck: ConditionCheck? {
        conditionChecks.max(by: { $0.checkedAt ?? .distantPast < $1.checkedAt ?? .distantPast })
    }

    static func == (lhs: Towel, rhs: Towel) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.location == rhs.location &&
        lhs.iconName == rhs.iconName &&
        lhs.exchangeIntervalDays == rhs.exchangeIntervalDays &&
        lhs.createdAt == rhs.createdAt &&
        lhs.lastExchangedAt == rhs.lastExchangedAt &&
        lhs.records.count == rhs.records.count &&
        lhs.conditionChecks.count == rhs.conditionChecks.count
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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
