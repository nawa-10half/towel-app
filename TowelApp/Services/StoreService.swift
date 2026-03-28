import Foundation
import StoreKit

@Observable
@MainActor
final class StoreService {
    static let shared = StoreService()

    var isPro = false
    var products: [Product] = []
    var purchaseError: String?
    var isPurchasing = false

    private var transactionUpdatesTask: Task<Void, Never>?

    private var monthlyProductId: String {
        Bundle.main.object(forInfoDictionaryKey: "ProMonthlyProductID") as? String ?? ""
    }

    private var lifetimeProductId: String {
        Bundle.main.object(forInfoDictionaryKey: "ProLifetimeProductID") as? String ?? ""
    }

    var monthlyProduct: Product? {
        products.first { $0.id == monthlyProductId }
    }

    var lifetimeProduct: Product? {
        products.first { $0.id == lifetimeProductId }
    }

    private init() {}

    // MARK: - Start Observing

    func startObserving() {
        transactionUpdatesTask?.cancel()

        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self.refreshEntitlements()
                }
            }
        }

        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    // MARK: - Load Products

    private func loadProducts() async {
        let ids = [monthlyProductId, lifetimeProductId].filter { !$0.isEmpty }
        guard !ids.isEmpty else { return }

        do {
            products = try await Product.products(for: Set(ids))
        } catch {
            purchaseError = String(localized: "プロダクト情報の取得に失敗しました")
        }
    }

    // MARK: - Refresh Entitlements

    func refreshEntitlements() async {
        var hasPro = false

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                let id = transaction.productID
                if id == monthlyProductId || id == lifetimeProductId {
                    hasPro = true
                }
            }
        }

        isPro = hasPro
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                } else {
                    purchaseError = String(localized: "購入の検証に失敗しました")
                }
            case .pending:
                break
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = String(localized: "購入に失敗しました: \(error.localizedDescription)")
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseError = String(localized: "購入の復元に失敗しました: \(error.localizedDescription)")
        }
    }
}
