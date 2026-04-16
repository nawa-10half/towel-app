import SwiftUI

struct TowelRowView: View {
    let towel: Towel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: towel.iconName)
                .font(.title2)
                .foregroundStyle(statusColor)
                .frame(width: 40, height: 40)
                .background(statusColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    if towel.status == .ok {
                        SparkleOverlay(sparkles: [
                            (x: 34, y: 6, size: 10, delay: 0.0),
                            (x: 6, y: 32, size: 8, delay: 0.18),
                            (x: 30, y: 30, size: 6, delay: 0.36)
                        ])
                    }
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(towel.name)
                    .font(.headline)

                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.caption2)
                    Text(towel.location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(formatDaysAgo(towel.daysSinceLastExchange))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(towel.status.label)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(statusColor.opacity(0.15))
                .foregroundStyle(statusColor)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    private func formatDaysAgo(_ days: Int) -> String {
        switch days {
        case 0: return String(localized: "今日交換")
        default: return String(localized: "\(days)日前に交換")
        }
    }

    private var statusColor: Color {
        switch towel.status {
        case .ok: return .green
        case .soon: return .orange
        case .overdue: return .red
        }
    }
}


#Preview {
    let towel = Towel(name: "バスタオル", location: "浴室", iconName: "shower.fill", exchangeIntervalDays: 3)
    return List {
        TowelRowView(towel: towel)
    }
}
