import SwiftUI

struct ConditionCheckRowView: View {
    let conditionCheck: ConditionCheck

    var body: some View {
        HStack(spacing: 12) {
            if let uiImage = UIImage(data: conditionCheck.photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(conditionCheck.checkedAt.formatted日本語)
                    .font(.subheadline)

                Text(conditionCheck.recommendation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(conditionCheck.overallScore)")
                .font(.headline.bold())
                .foregroundStyle(scoreBadgeColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(scoreBadgeColor.opacity(0.15))
                .clipShape(Capsule())
        }
    }

    private var scoreBadgeColor: Color {
        switch conditionCheck.overallScore {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
}
