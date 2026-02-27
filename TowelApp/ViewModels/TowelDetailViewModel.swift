import Foundation
import Observation
import WidgetKit
import UIKit

@Observable
@MainActor
final class TowelDetailViewModel {
    let towelId: String
    var errorMessage: String?
    var isAssessing = false
    var dailyAssessmentCount: Int = 0
    var canAssess: Bool {
        let isPro = StoreService.shared.isPro
        let baseLimit = ProLimits.maxDailyAssessments(isPro: isPro)
        let bonus = isPro ? 0 : AdService.shared.bonusAssessmentCount
        return dailyAssessmentCount < baseLimit + bonus
    }
    var showAdButton: Bool {
        !canAssess && !StoreService.shared.isPro && AdService.shared.isRewardedAdReady
    }
    var assessmentSucceeded = false
    var showingPaywall = false

    init(towelId: String) {
        self.towelId = towelId
    }

    func startListening() {
        FirestoreService.shared.startSubcollectionListeners(towelId: towelId)
    }

    func stopListening() {
        FirestoreService.shared.stopSubcollectionListeners(towelId: towelId)
    }

    var towel: Towel? {
        FirestoreService.shared.towels.first(where: { $0.id == towelId })
    }

    var sortedRecords: [ExchangeRecord] {
        guard let towel else { return [] }
        return towel.records.sorted { $0.exchangedAt ?? .distantPast > $1.exchangedAt ?? .distantPast }
    }

    var sortedConditionChecks: [ConditionCheck] {
        guard let towel else { return [] }
        return towel.conditionChecks.sorted { $0.checkedAt ?? .distantPast > $1.checkedAt ?? .distantPast }
    }

    // MARK: - Pagination

    var hasMoreRecords: Bool {
        FirestoreService.shared.hasMoreRecords(towelId: towelId)
    }

    var hasMoreConditionChecks: Bool {
        FirestoreService.shared.hasMoreConditionChecks(towelId: towelId)
    }

    func loadAllRecords() {
        FirestoreService.shared.loadAllRecords(towelId: towelId)
    }

    func loadAllConditionChecks() {
        FirestoreService.shared.loadAllConditionChecks(towelId: towelId)
    }

    func deleteRecord(_ record: ExchangeRecord) {
        guard let recordId = record.id else { return }
        do {
            try FirestoreService.shared.deleteRecord(towelId: towelId, recordId: recordId)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            errorMessage = "交換記録の削除に失敗しました: \(error.localizedDescription)"
        }
    }

    func loadDailyAssessmentCount() async {
        AdService.shared.resetIfNewDay()
        dailyAssessmentCount = (try? await FirestoreService.shared.getDailyAssessmentCount()) ?? 0
    }

    func assessCondition(imageData: Data, image: UIImage) async {
        guard canAssess else {
            if !StoreService.shared.isPro {
                showingPaywall = true
            }
            return
        }

        isAssessing = true
        defer { isAssessing = false }

        do {
            let result = try await ConditionCheckService.shared.assessCondition(
                imageData: imageData,
                towelName: towel?.name ?? "",
                towelLocation: towel?.location ?? ""
            )

            // Save condition check to Firestore first to get the ID
            let checkId = try await FirestoreService.shared.saveConditionCheck(
                towelId: towelId,
                photoURL: nil,
                overallScore: result.overallScore,
                colorFadingScore: result.colorFadingScore,
                stainScore: result.stainScore,
                fluffinessScore: result.fluffinessScore,
                frayingScore: result.frayingScore,
                comment: result.comment,
                recommendation: result.recommendation
            )

            // Upload photo to Storage and update the check with photoURL
            let photoURL = try await StorageService.shared.uploadConditionPhoto(
                towelId: towelId,
                checkId: checkId,
                image: image
            )

            // Update the Firestore document with the photo URL
            try await FirestoreService.shared.updateConditionCheckPhotoURL(
                towelId: towelId,
                checkId: checkId,
                photoURL: photoURL
            )

            // Count up only on success
            try? await FirestoreService.shared.incrementDailyAssessmentCount()
            dailyAssessmentCount += 1
            assessmentSucceeded.toggle()
        } catch {
            errorMessage = "状態診断に失敗しました: \(error.localizedDescription)"
        }
    }

    func deleteConditionCheck(_ check: ConditionCheck) {
        guard let checkId = check.id else { return }
        // Delete photo from Storage in background (best-effort)
        if check.photoURL != nil {
            Task {
                try? await StorageService.shared.deleteConditionPhoto(towelId: towelId, checkId: checkId)
            }
        }
        do {
            try FirestoreService.shared.deleteConditionCheck(towelId: towelId, checkId: checkId)
        } catch {
            errorMessage = "診断記録の削除に失敗しました: \(error.localizedDescription)"
        }
    }
}
