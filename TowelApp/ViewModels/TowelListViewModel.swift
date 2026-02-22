import Foundation
import Observation
import WidgetKit

@Observable
final class TowelListViewModel {
    var searchText = ""
    var errorMessage: String?

    func filteredTowels(_ towels: [Towel]) -> [Towel] {
        guard !searchText.isEmpty else { return towels }
        return towels.filter { towel in
            towel.name.localizedCaseInsensitiveContains(searchText) ||
            towel.location.localizedCaseInsensitiveContains(searchText)
        }
    }

    @MainActor
    func deleteTowel(_ towel: Towel) {
        guard let towelId = towel.id else { return }
        NotificationService.shared.cancelNotification(for: towel)
        do {
            try FirestoreService.shared.deleteTowel(towelId)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            errorMessage = "タオルの削除に失敗しました: \(error.localizedDescription)"
        }
    }

    func sortedByStatus(_ towels: [Towel]) -> [Towel] {
        towels.sorted { lhs, rhs in
            let lhsOrder = statusOrder(lhs.status)
            let rhsOrder = statusOrder(rhs.status)
            if lhsOrder != rhsOrder {
                return lhsOrder < rhsOrder
            }
            return lhs.daysSinceLastExchange > rhs.daysSinceLastExchange
        }
    }

    private func statusOrder(_ status: TowelStatus) -> Int {
        switch status {
        case .overdue: return 0
        case .soon: return 1
        case .ok: return 2
        }
    }
}
