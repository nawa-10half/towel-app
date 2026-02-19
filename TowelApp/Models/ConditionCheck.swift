import Foundation
import SwiftData

@Model
final class ConditionCheck {
    var id: UUID = UUID()
    var checkedAt: Date = Date.now
    @Attribute(.externalStorage) var photoData: Data = Data()
    var overallScore: Int = 0
    var colorFadingScore: Int = 0
    var stainScore: Int = 0
    var fluffinessScore: Int = 0
    var frayingScore: Int = 0
    var comment: String = ""
    var recommendation: String = ""

    var towel: Towel?

    init(
        id: UUID = UUID(),
        checkedAt: Date = Date.now,
        photoData: Data,
        overallScore: Int,
        colorFadingScore: Int,
        stainScore: Int,
        fluffinessScore: Int,
        frayingScore: Int,
        comment: String,
        recommendation: String,
        towel: Towel? = nil
    ) {
        self.id = id
        self.checkedAt = checkedAt
        self.photoData = photoData
        self.overallScore = overallScore
        self.colorFadingScore = colorFadingScore
        self.stainScore = stainScore
        self.fluffinessScore = fluffinessScore
        self.frayingScore = frayingScore
        self.comment = comment
        self.recommendation = recommendation
        self.towel = towel
    }
}
