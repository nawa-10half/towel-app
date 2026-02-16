import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: TowelWidgetEntry

    var body: some View {
        if let towel = entry.towels.first {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: towel.iconName)
                        .font(.title2)
                        .foregroundStyle(statusColor(towel.status))
                    Spacer()
                    statusBadge(towel.status)
                }

                Text(towel.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(towel.location)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Text("\(towel.daysSinceLastExchange)日経過")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(statusColor(towel.status))
            }
            .widgetURL(URL(string: "towelapp://towel/\(towel.id)"))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("タオルを追加")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private func statusColor(_ status: WidgetTowelStatus) -> Color {
    switch status {
    case .ok: return .green
    case .soon: return .orange
    case .overdue: return .red
    }
}

private func statusBadge(_ status: WidgetTowelStatus) -> some View {
    Text(status.label)
        .font(.system(size: 10))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(statusColor(status).opacity(0.2))
        .foregroundStyle(statusColor(status))
        .clipShape(Capsule())
}
