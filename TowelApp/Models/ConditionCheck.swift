import Foundation
import FirebaseFirestore

struct ConditionCheck: Codable, Identifiable {
    @DocumentID var id: String?
    @ServerTimestamp var checkedAt: Date?
    var photoURL: String?
    var overallScore: Int = 0
    var colorFadingScore: Int = 0
    var stainScore: Int = 0
    var fluffinessScore: Int = 0
    var frayingScore: Int = 0
    var comment: String = ""
    var recommendation: String = ""
}
