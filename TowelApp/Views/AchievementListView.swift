import SwiftUI

struct AchievementListView: View {
    @State private var achievementService = AchievementService.shared
    @State private var selected: AchievementDefinition?

    private let columns = [
        GridItem(.adaptive(minimum: 92), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                section(title: String(localized: "個人バッジ"), items: AchievementCatalog.personal)
                section(title: String(localized: "家族バッジ"), items: AchievementCatalog.family)
                section(title: String(localized: "Pro限定バッジ"), items: AchievementCatalog.proOnly)
            }
            .padding()
        }
        .navigationTitle("バッジ")
        .sheet(item: $selected) { def in
            AchievementDetailView(definition: def)
                .presentationDetents([.medium])
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("\(achievementService.unlockedCount) / \(achievementService.totalCount)")
                .font(.largeTitle.bold())
            Text("獲得したバッジ")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func section(title: String, items: [AchievementDefinition]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items) { def in
                    Button {
                        selected = def
                    } label: {
                        AchievementBadgeCell(
                            definition: def,
                            isUnlocked: achievementService.isUnlocked(def.id)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct AchievementBadgeCell: View {
    let definition: AchievementDefinition
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: 6) {
            if isUnlocked {
                Image(definition.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(definition.tier.color, lineWidth: 3)
                    )
                    .overlay {
                        SparkleOverlay(
                            color: .yellow,
                            shadowColor: definition.tier.color,
                            sparkles: [
                                (x: 62, y: 10, size: 8, delay: 0.0),
                                (x: 8, y: 56, size: 7, delay: 0.2),
                                (x: 56, y: 58, size: 5, delay: 0.4)
                            ]
                        )
                    }
            } else {
                ZStack {
                    Image(definition.iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                        .saturation(0)
                        .opacity(0.25)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                }
            }
            Text(definition.title)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(isUnlocked ? .primary : .secondary)
        }
    }

    private var ringColor: Color {
        definition.tier.color
    }
}

struct AchievementDetailView: View {
    let definition: AchievementDefinition
    @State private var achievementService = AchievementService.shared
    @Environment(\.dismiss) private var dismiss

    private var isUnlocked: Bool { achievementService.isUnlocked(definition.id) }

    var body: some View {
        VStack(spacing: 20) {
            AchievementBadgeCell(definition: definition, isUnlocked: isUnlocked)
                .scaleEffect(1.4)
                .padding(.top, 24)

            Text(definition.title)
                .font(.title2.bold())

            Text(definition.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if isUnlocked, let date = unlockedDate {
                Text("\(date.formatted(date: .long, time: .omitted)) 獲得")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                progressView
            }

            if isUnlocked && !definition.isGroupAchievement {
                Button {
                    guard NetworkMonitor.shared.isConnected else { return }
                    Task {
                        let newValue = achievementService.pinnedBadgeId == definition.id ? nil : definition.id
                        await achievementService.updatePinnedBadge(newValue)
                    }
                } label: {
                    Label(
                        achievementService.pinnedBadgeId == definition.id
                            ? String(localized: "表示バッジを解除")
                            : String(localized: "このバッジを表示"),
                        systemImage: "pin.fill"
                    )
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding()
    }

    private var unlockedDate: Date? {
        achievementService.unlocked[definition.id]?.unlockedAt
    }

    private var currentAverage: Int {
        guard achievementService.conditionScoreCount > 0 else { return 0 }
        return achievementService.conditionScoreSum / achievementService.conditionScoreCount
    }

    @ViewBuilder
    private var progressView: some View {
        switch definition.requirement {
        case .exchangeCount(let n):
            progressBar(current: achievementService.totalExchangeCount, target: n)
        case .conditionCheckCount(let n):
            progressBar(current: achievementService.totalConditionCheckCount, target: n)
        case .groupExchangeCount(let n):
            progressBar(current: achievementService.groupTotalExchangeCount, target: n)
        case .averageScore(let min, let minChecks):
            VStack(spacing: 4) {
                Text("平均スコア \(currentAverage) / \(Int(min))")
                Text("診断回数 \(achievementService.conditionScoreCount) / \(minChecks)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        default:
            Text("未獲得")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func progressBar(current: Int, target: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ProgressView(value: Double(min(current, target)), total: Double(target))
            Text("\(min(current, target)) / \(target)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 220)
    }
}

#Preview {
    NavigationStack {
        AchievementListView()
    }
}
