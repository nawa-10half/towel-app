import Foundation
import SwiftData

@Model
final class ConditionCheck {
    @Attribute(.unique) var id: UUID
    var checkedAt: Date
    @Attribute(.externalStorage) var photoData: Data
    var overallScore: Int
    var colorFadingScore: Int
    var stainScore: Int
    var fluffinessScore: Int
    var frayingScore: Int
    var comment: String
    var recommendation: String

    var towel: Towel?

    init(
        id: UUID = UUID(),
        checkedAt: Date = .now,
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
