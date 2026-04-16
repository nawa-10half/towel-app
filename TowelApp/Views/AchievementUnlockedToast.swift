import SwiftUI

struct AchievementUnlockedToast: ViewModifier {
    @State private var achievementService = AchievementService.shared
    @State private var currentId: String?
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isVisible, let id = currentId, let def = AchievementCatalog.definition(for: id) {
                    toast(for: def)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                        .padding(.horizontal)
                }
            }
            .onChange(of: achievementService.pendingToasts.count) { _, _ in
                showNextIfNeeded()
            }
            .onAppear { showNextIfNeeded() }
    }

    private func showNextIfNeeded() {
        guard currentId == nil,
              let next = achievementService.pendingToasts.first else { return }
        currentId = next
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isVisible = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) {
                    isVisible = false
                }
            }
            try? await Task.sleep(for: .milliseconds(300))
            await MainActor.run {
                if !achievementService.pendingToasts.isEmpty {
                    achievementService.pendingToasts.removeFirst()
                }
                currentId = nil
                showNextIfNeeded()
            }
        }
    }

    private func toast(for def: AchievementDefinition) -> some View {
        HStack(spacing: 12) {
            Image(def.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("バッジを獲得！")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(def.title)
                    .font(.subheadline.bold())
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
    }

    private func tierColor(for tier: AchievementTier) -> Color {
        switch tier {
        case .bronze: return .brown
        case .silver: return .gray
        case .gold: return .yellow
        }
    }
}

extension View {
    func achievementUnlockedToast() -> some View {
        modifier(AchievementUnlockedToast())
    }
}
