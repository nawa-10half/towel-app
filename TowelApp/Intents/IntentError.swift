import Foundation
import AppIntents

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case towelNotFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .towelNotFound:
            return "指定されたタオルが見つかりませんでした"
        }
    }
}
