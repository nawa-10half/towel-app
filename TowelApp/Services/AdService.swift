import Foundation
import GoogleMobileAds
import UIKit

@Observable
@MainActor
final class AdService: NSObject {
    static let shared = AdService()

    var isRewardedAdReady = false
    var bonusAssessmentCount = 0

    private var rewardedAd: RewardedAd?
    private var lastResetDate: String = ""

    private var adUnitId: String {
        Bundle.main.object(forInfoDictionaryKey: "AdMobRewardedAdUnitID") as? String ?? ""
    }

    private override init() {
        super.init()
    }

    // MARK: - Daily Reset

    private var todayDateKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "ja_JP")
        f.timeZone = .current
        return f.string(from: Date())
    }

    func resetIfNewDay() {
        let today = todayDateKey
        if lastResetDate != today {
            bonusAssessmentCount = 0
            lastResetDate = today
        }
    }

    // MARK: - Load Ad

    func loadRewardedAd() {
        guard !StoreService.shared.isPro else { return }
        guard !adUnitId.isEmpty else { return }

        Task {
            do {
                rewardedAd = try await RewardedAd.load(with: adUnitId, request: Request())
                rewardedAd?.fullScreenContentDelegate = self
                isRewardedAdReady = true
            } catch {
                isRewardedAdReady = false
            }
        }
    }

    // MARK: - Show Ad

    func showRewardedAd() {
        guard !StoreService.shared.isPro else { return }
        guard let ad = rewardedAd else { return }

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        // Find topmost presented VC
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        ad.present(from: topVC) { [weak self] in
            guard let self else { return }
            let reward = ad.adReward
            _ = reward // reward acknowledged
            self.resetIfNewDay()
            self.bonusAssessmentCount += 1
            self.isRewardedAdReady = false
            self.loadRewardedAd()
        }
    }
}

// MARK: - FullScreenContentDelegate

extension AdService: FullScreenContentDelegate {
    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            self.isRewardedAdReady = false
            self.loadRewardedAd()
        }
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            if !self.isRewardedAdReady {
                self.loadRewardedAd()
            }
        }
    }
}
