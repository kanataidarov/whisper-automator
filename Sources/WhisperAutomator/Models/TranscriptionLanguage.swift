import Foundation

enum TranscriptionLanguage: String, CaseIterable, Identifiable, Sendable {
    case russian = "ru"
    case kazakh = "kk"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .russian: "Русский"
        case .kazakh: "Қазақша"
        case .english: "English"
        }
    }
}
