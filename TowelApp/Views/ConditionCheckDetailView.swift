import SwiftUI

struct ConditionCheckDetailView: View {
    let conditionCheck: ConditionCheck

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                photoSection
                overallScoreSection
                detailScoresSection
                commentSection
                recommendationSection
            }
            .padding()
        }
        .navigationTitle("状態診断")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var photoSection: some View {
        Group {
            if let urlString = conditionCheck.photoURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure:
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                            .frame(height: 200)
                    case .empty:
                        ProgressView()
                            .frame(height: 200)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
    }

    private var overallScoreSection: some View {
        VStack(spacing: 8) {
            Text("総合スコア")
                .font(.headline)
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(conditionCheck.overallScore) / 100)
                    .stroke(scoreColor(conditionCheck.overallScore), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                Text("\(conditionCheck.overallScore)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor(conditionCheck.overallScore))
            }

            Text((conditionCheck.checkedAt ?? .now).formattedLocalized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var detailScoresSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            scoreCard(title: "色褪せ", score: conditionCheck.colorFadingScore, icon: "paintpalette")
            scoreCard(title: "汚れ", score: conditionCheck.stainScore, icon: "drop.triangle")
            scoreCard(title: "ふわふわ感", score: conditionCheck.fluffinessScore, icon: "cloud")
            scoreCard(title: "ほつれ", score: conditionCheck.frayingScore, icon: "scissors")
        }
    }

    private func scoreCard(title: String, score: Int, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(scoreColor(score))

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(score)")
                .font(.title2.bold())
                .foregroundStyle(scoreColor(score))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(scoreColor(score).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var commentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("コメント", systemImage: "text.bubble")
                .font(.headline)
            Text(conditionCheck.comment)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("推奨アクション", systemImage: "lightbulb")
                .font(.headline)
            Text(conditionCheck.recommendation)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.indigo.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
}
