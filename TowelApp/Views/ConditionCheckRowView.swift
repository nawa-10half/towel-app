import SwiftUI

struct ConditionCheckRowView: View {
    let conditionCheck: ConditionCheck

    var body: some View {
        HStack(spacing: 12) {
            if let urlString = conditionCheck.photoURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure:
                        imagePlaceholder
                    case .empty:
                        ProgressView()
                            .frame(width: 50, height: 50)
                    @unknown default:
                        imagePlaceholder
                    }
                }
            } else {
                imagePlaceholder
            }

            VStack(alignment: .leading, spacing: 4) {
                Text((conditionCheck.checkedAt ?? .now).formattedLocalized)
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

    private var imagePlaceholder: some View {
        Image(systemName: "photo")
            .foregroundStyle(.secondary)
            .frame(width: 50, height: 50)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
