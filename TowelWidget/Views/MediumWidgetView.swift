import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let entry: TowelWidgetEntry

    var body: some View {
        if entry.towels.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("タオルを追加してください")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            let displayTowels = Array(entry.towels.prefix(4))
            VStack(alignment: .leading, spacing: 4) {
                ForEach(displayTowels) { towel in
                    Link(destination: URL(string: "towelapp://towel/\(towel.id)")!) {
                        HStack(spacing: 8) {
                            Image(systemName: towel.iconName)
                                .font(.body)
                                .foregroundStyle(statusColor(towel.status))
                                .frame(width: 20)

                            Text(towel.name)
                                .font(.subheadline)
                                .lineLimit(1)

                            Spacer()

                            Text("\(towel.daysSinceLastExchange)日")
                                .font(.subheadline)
                                .foregroundStyle(statusColor(towel.status))
                                .fontWeight(.semibold)

                            Circle()
                                .fill(statusColor(towel.status))
                                .frame(width: 8, height: 8)
                        }
                    }

                    if towel.id != displayTowels.last?.id {
                        Divider()
                    }
                }
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
