import SwiftUI
import StoreKit

enum ProFeature {
    case assessment
    case towelLimit
    case groupMembers
    case history

    var title: String {
        switch self {
        case .assessment: return "AI状態診断"
        case .towelLimit: return "タオル登録数"
        case .groupMembers: return "グループメンバー"
        case .history: return "診断履歴"
        }
    }

    var description: String {
        switch self {
        case .assessment: return "AIによる状態診断が無制限に"
        case .towelLimit: return "タオルを何枚でも登録可能"
        case .groupMembers: return "グループメンバーを最大10人まで"
        case .history: return "すべての診断履歴を閲覧可能"
        }
    }

    var systemImage: String {
        switch self {
        case .assessment: return "sparkles"
        case .towelLimit: return "plus.circle"
        case .groupMembers: return "person.3"
        case .history: return "clock.arrow.circlepath"
        }
    }
}

struct ProPaywallView: View {
    let feature: ProFeature
    @Environment(\.dismiss) private var dismiss
    @State private var storeService = StoreService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    featuresSection
                    productsSection
                    restoreButton
                }
                .padding()
            }
            .navigationTitle("Pro プラン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .alert("エラー", isPresented: Binding(
                get: { storeService.purchaseError != nil },
                set: { if !$0 { storeService.purchaseError = nil } }
            )) {
                Button("OK") { storeService.purchaseError = nil }
            } message: {
                Text(storeService.purchaseError ?? "")
            }
            .onChange(of: storeService.isPro) { _, isPro in
                if isPro { dismiss() }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: feature.systemImage)
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text(feature.title)
                .font(.title2)
                .fontWeight(.bold)

            Text(feature.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 16)
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "sparkles", text: "AI状態診断が無制限")
            featureRow(icon: "plus.circle", text: "タオル登録数が無制限")
            featureRow(icon: "person.3", text: "グループメンバー最大10人")
            featureRow(icon: "clock.arrow.circlepath", text: "すべての診断履歴を閲覧")
            featureRow(icon: "nosign", text: "広告なし")
        }
        .padding()
        .background(.fill.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }

    private var productsSection: some View {
        VStack(spacing: 12) {
            if let lifetime = storeService.lifetimeProduct {
                productCard(product: lifetime, badge: "買い切り")
            }
            if let monthly = storeService.monthlyProduct {
                productCard(product: monthly, badge: nil)
            }

            if storeService.products.isEmpty {
                Text("プロダクト情報を読み込み中...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func productCard(product: Product, badge: String?) -> some View {
        Button {
            Task { await storeService.purchase(product) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(product.displayName)
                            .fontWeight(.semibold)
                        if let badge {
                            Text(badge)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(product.displayPrice)
                    .fontWeight(.bold)
            }
            .padding()
            .background(.fill.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(storeService.isPurchasing)
        .opacity(storeService.isPurchasing ? 0.5 : 1)
    }

    private var restoreButton: some View {
        Button("購入を復元") {
            Task { await storeService.restorePurchases() }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

#Preview {
    ProPaywallView(feature: .assessment)
}
