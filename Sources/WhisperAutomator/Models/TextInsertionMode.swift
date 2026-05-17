import Foundation

enum TextInsertionMode: String, CaseIterable, Identifiable, Sendable {
    case paste = "paste"
    case typeText = "typeText"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .paste: "Paste (Cmd+V)"
        case .typeText: "Type ASCII (character-by-character)"
        }
    }

    var description: String {
        switch self {
        case .paste:
            "Uses CGEvent Cmd+V. Fastest for native macOS apps."
        case .typeText:
            "Sends real US-keyboard keycodes with a 2 ms delay. Non-ASCII text is transliterated to Latin. Works over RDP."
        }
    }
}
