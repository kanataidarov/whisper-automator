@preconcurrency import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    nonisolated(unsafe) static let holdToTalk = Self(
        "holdToTalk",
        default: .init(.space, modifiers: [.option])
    )
}
