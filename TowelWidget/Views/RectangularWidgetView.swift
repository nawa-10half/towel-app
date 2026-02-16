import SwiftUI
import WidgetKit

struct RectangularWidgetView: View {
    let entry: TowelWidgetEntry

    var body: some View {
        if entry.towels.isEmpty {
            Text("タオルを追加してください")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            let displayTowels = Array(entry.towels.prefix(2))
            VStack(alignment: .leading, spacing: 4) {
                ForEach(displayTowels) { towel in
                    HStack(spacing: 4) {
                        Image(systemName: towel.iconName)
                            .font(.caption)
                            .frame(width: 14)
                        Text(towel.name)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text("\(towel.daysSinceLastExchange)日")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .widgetAccentable()
                    }
                }
            }
        }
    }
}
