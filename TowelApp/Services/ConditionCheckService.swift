import Foundation

struct ConditionAssessment: Codable {
    let overallScore: Int
    let colorFadingScore: Int
    let stainScore: Int
    let fluffinessScore: Int
    let frayingScore: Int
    let comment: String
    let recommendation: String

    enum CodingKeys: String, CodingKey {
        case overallScore = "overall_score"
        case colorFadingScore = "color_fading_score"
        case stainScore = "stain_score"
        case fluffinessScore = "fluffiness_score"
        case frayingScore = "fraying_score"
        case comment
        case recommendation
    }
}

enum ConditionCheckError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case missingAPIURL
    case imageTooLarge
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "サーバーからの応答を解析できませんでした"
        case .httpError(let code):
            return "サーバーエラーが発生しました (HTTP \(code))"
        case .serverError(let message):
            return "サーバーエラー: \(message)"
        case .missingAPIURL:
            return "APIのURLが設定されていません"
        case .imageTooLarge:
            return "画像サイズが大きすぎます（5MB以下にしてください）"
        case .rateLimited:
            return "しばらく時間をおいてから再度お試しください"
        }
    }
}

final class ConditionCheckService: @unchecked Sendable {
    static let shared = ConditionCheckService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        self.session = URLSession(configuration: config)
    }

    private static let maxImageSize = 5 * 1024 * 1024 // 5MB

    func assessCondition(imageData: Data, towelName: String, towelLocation: String) async throws -> ConditionAssessment {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "ConditionCheckAPIURL") as? String,
              let url = URL(string: urlString) else {
            throw ConditionCheckError.missingAPIURL
        }

        guard imageData.count <= Self.maxImageSize else {
            throw ConditionCheckError.imageTooLarge
        }

        let base64Image = imageData.base64EncodedString()
        let requestBody: [String: Any] = [
            "image": base64Image,
            "towel_name": towelName,
            "towel_location": towelLocation
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConditionCheckError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 429 {
                throw ConditionCheckError.rateLimited
            }
            if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorBody["error"] as? String {
                throw ConditionCheckError.serverError(message)
            }
            throw ConditionCheckError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(ConditionAssessment.self, from: data)
    }
}
