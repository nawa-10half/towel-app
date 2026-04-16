import SwiftUI

struct UserProfileBadgeView: View {
    @State private var authService = AuthService.shared
    @State private var achievementService = AchievementService.shared

    var body: some View {
        HStack(spacing: 6) {
            UserProfileIconView(
                iconName: authService.iconName,
                colorName: authService.iconColor,
                size: 32
            )

            if let badge = achievementService.displayBadge {
                Image(badge.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
            }
        }
    }

    private func tierColor(for tier: AchievementTier) -> Color {
        switch tier {
        case .bronze: return .brown
        case .silver: return .gray
        case .gold: return .yellow
        }
    }
}

struct UserProfileSheet: View {
    @State private var authService = AuthService.shared
    @State private var achievementService = AchievementService.shared
    @State private var showingEdit = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    UserProfileIconView(
                        iconName: authService.iconName,
                        colorName: authService.iconColor,
                        size: 104
                    )
                    .padding(.top, 24)

                    Text(authService.displayName.isEmpty ? String(localized: "名称未設定") : authService.displayName)
                        .font(.title2.bold())

                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.yellow)
                        Text("\(achievementService.unlockedCount) / \(achievementService.totalCount) バッジ")
                            .font(.subheadline)
                    }

                    if !recentBadges.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("最近獲得したバッジ")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(recentBadges) { def in
                                        AchievementBadgeCell(definition: def, isUnlocked: true)
                                            .frame(width: 84)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    NavigationLink {
                        AchievementListView()
                    } label: {
                        Label("すべてのバッジを見る", systemImage: "chevron.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)

                    Button {
                        showingEdit = true
                    } label: {
                        Label("プロフィールを編集", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
            .navigationTitle("プロフィール")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(isPresented: $showingEdit) {
                UserProfileEditView()
            }
        }
    }

    private var recentBadges: [AchievementDefinition] {
        achievementService.unlocked.values
            .sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }
            .prefix(5)
            .compactMap { AchievementCatalog.definition(for: $0.id ?? "") }
    }
}
