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
        case 0: return "今日交換"
        default: return "\(days)日前に交換"
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
