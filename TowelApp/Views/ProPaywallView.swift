import SwiftUI
import StoreKit

enum ProFeature {
    case assessment
    case towelLimit
    case groupMembers
    case history

    var title: String {
        switch self {
        case .assessment: return String(localized: "AI状態診断")
        case .towelLimit: return String(localized: "アイテム登録数")
        case .groupMembers: return String(localized: "グループメンバー")
        case .history: return String(localized: "診断履歴")
        }
    }

    var description: String {
        switch self {
        case .assessment: return String(localized: "AIによる状態診断が無制限に")
        case .towelLimit: return String(localized: "アイテムを何個でも登録可能")
        case .groupMembers: return String(localized: "グループメンバーを最大10人まで")
        case .history: return String(localized: "すべての診断履歴を閲覧可能")
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
                    legalLinks
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
            featureRow(icon: "plus.circle", text: "アイテム登録数が無制限")
            featureRow(icon: "person.3", text: "グループメンバー最大10人")
            featureRow(icon: "clock.arrow.circlepath", text: "すべての診断履歴を閲覧")
            featureRow(icon: "nosign", text: "広告なし")
        }
        .padding()
        .background(.fill.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func featureRow(icon: String, text: LocalizedStringKey) -> some View {
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
                productCard(product: lifetime, badge: String(localized: "買い切り"))
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
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .fontWeight(.bold)
                    if let period = product.subscription?.subscriptionPeriod {
                        Text(period.displayUnit)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
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

    private var legalLinks: some View {
        HStack(spacing: 16) {
            Link("プライバシーポリシー", destination: URL(string: "https://kaetao-c43f1.web.app/privacy-policy")!)
            Link("利用規約", destination: URL(string: "https://kaetao-c43f1.web.app/terms-of-use")!)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}

private extension Product.SubscriptionPeriod {
    var displayUnit: String {
        switch unit {
        case .day: return value == 7 ? String(localized: "/ 週") : String(localized: "/ \(value)日")
        case .week: return String(localized: "/ 週")
        case .month: return value == 1 ? String(localized: "/ 月") : String(localized: "/ \(value)ヶ月")
        case .year: return value == 1 ? String(localized: "/ 年") : String(localized: "/ \(value)年")
        @unknown default: return ""
        }
    }
}

#Preview {
    ProPaywallView(feature: .assessment)
}
