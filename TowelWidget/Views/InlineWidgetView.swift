import SwiftUI
import WidgetKit

struct InlineWidgetView: View {
    let entry: TowelWidgetEntry

    var body: some View {
        if let towel = entry.towels.first, towel.status != .ok {
            let emoji = towel.status == .overdue ? "\u{1F534}" : "\u{1F7E1}"
            Text("\(emoji) \(towel.name) \(towel.daysSinceLastExchange)日経過")
        } else {
            Text("\u{2705} すべてOK")
        }
    }
}
