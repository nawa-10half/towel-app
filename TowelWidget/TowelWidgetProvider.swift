import WidgetKit
import SwiftData

struct TowelWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TowelWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TowelWidgetEntry) -> Void) {
        let entry = fetchEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TowelWidgetEntry>) -> Void) {
        let entry = fetchEntry()

        let calendar = Calendar.current
        let nextMidnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now) ?? .now)

        let timeline = Timeline(entries: [entry], policy: .after(nextMidnight))
        completion(timeline)
    }

    private func fetchEntry() -> TowelWidgetEntry {
        do {
            let container = SharedModelContainer.shared
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<Towel>()
            let towels = try context.fetch(descriptor)

            let snapshots = towels.map { towel in
                TowelSnapshot(
                    id: towel.id.uuidString,
                    name: towel.name,
                    location: towel.location,
                    iconName: towel.iconName,
                    daysSinceLastExchange: towel.daysSinceLastExchange,
                    exchangeIntervalDays: towel.exchangeIntervalDays,
                    status: widgetStatus(from: towel)
                )
            }.sorted { lhs, rhs in
                if lhs.status.sortOrder != rhs.status.sortOrder {
                    return lhs.status.sortOrder < rhs.status.sortOrder
                }
                return lhs.daysSinceLastExchange > rhs.daysSinceLastExchange
            }

            return TowelWidgetEntry(date: .now, towels: snapshots)
        } catch {
            return TowelWidgetEntry(date: .now, towels: [])
        }
    }

    private func widgetStatus(from towel: Towel) -> WidgetTowelStatus {
        let remaining = Calendar.current.dateComponents(
            [.day], from: .now, to: towel.nextExchangeDate
        ).day ?? 0

        if remaining < 0 {
            return .overdue
        } else if remaining <= 1 {
            return .soon
        } else {
            return .ok
        }
    }
}
