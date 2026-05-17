import AppKit
import UserNotifications
import os.log

private let logger = Logger(subsystem: "WhisperAutomator", category: "TextInsertion")

enum TextInsertionService {
    private static let vKeyCode: CGKeyCode = 0x09

    static func insert(_ text: String) {
        guard !text.isEmpty else {
            logger.warning("insert() called with empty text, ignoring")
            return
        }

        guard AXIsProcessTrusted() else {
            logger.warning("Accessibility not granted – copying to clipboard only")
            copyToClipboard(text)
            sendUserNotification(
                title: "Text copied to clipboard",
                body: "Grant Accessibility access in System Settings to auto-type."
            )
            return
        }

        pasteText(text)
    }

    private static func pasteText(_ text: String) {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        usleep(50_000) // 50 ms – let the pasteboard sync

        guard let src = CGEventSource(stateID: .combinedSessionState) else {
            logger.error("Failed to create CGEventSource")
            return
        }

        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cgSessionEventTap)

        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cgSessionEventTap)

        logger.info("Pasted \(text.count) characters via Cmd+V")

        usleep(300_000) // 300 ms – let the target app process the paste

        if let previous = previousContents {
            pasteboard.clearContents()
            pasteboard.setString(previous, forType: .string)
        }
    }

    private static func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private static func sendUserNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
