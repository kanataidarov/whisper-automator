import AppKit
import UserNotifications
import os.log

private let logger = Logger(subsystem: "WhisperAutomator", category: "TextInsertion")

enum TextInsertionService {
    private static let vKeyCode: CGKeyCode = 0x09

    private static var insertionMode: TextInsertionMode {
        let stored = UserDefaults.standard.string(forKey: "textInsertionMode")
            ?? TextInsertionMode.paste.rawValue
        // Obsolete mode removed from the app; treat as paste.
        if stored == "pasteViaSystemEvents" {
            return .paste
        }
        return TextInsertionMode(rawValue: stored) ?? .paste
    }

    static func insert(_ text: String, targetProcessIdentifier: pid_t? = nil) {
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

        switch insertionMode {
        case .paste:
            pasteViaCGEvent(text, targetProcessIdentifier: targetProcessIdentifier)
        case .typeText:
            typeText(text, targetProcessIdentifier: targetProcessIdentifier)
        }
    }

    // MARK: - Paste via CGEvent (native macOS apps)

    private static func pasteViaCGEvent(_ text: String, targetProcessIdentifier: pid_t?) {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        usleep(50_000)

        activateTargetApplication(processIdentifier: targetProcessIdentifier)

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

        logger.info("Pasted \(text.count) characters via CGEvent Cmd+V")

        usleep(300_000)

        if let previous = previousContents {
            pasteboard.clearContents()
            pasteboard.setString(previous, forType: .string)
        }
    }

    // MARK: - Type text character-by-character (ASCII keycodes, RDP-safe)

    private static func typeText(_ text: String, targetProcessIdentifier: pid_t?) {
        activateTargetApplication(processIdentifier: targetProcessIdentifier)

        let ascii = transliterateToASCII(text)

        guard let src = CGEventSource(stateID: .combinedSessionState) else {
            logger.error("Failed to create CGEventSource")
            return
        }

        for char in ascii {
            guard let mapping = asciiKeycodeMap[char] else { continue }

            let keyDown = CGEvent(keyboardEventSource: src, virtualKey: mapping.keyCode, keyDown: true)
            if mapping.shift { keyDown?.flags = .maskShift }
            keyDown?.post(tap: .cgSessionEventTap)

            let keyUp = CGEvent(keyboardEventSource: src, virtualKey: mapping.keyCode, keyDown: false)
            keyUp?.post(tap: .cgSessionEventTap)

            usleep(2_000) // 2 ms inter-key delay for RDP stability
        }

        logger.info("Typed \(ascii.count) ASCII characters via keycodes")
    }

    private static func transliterateToASCII(_ text: String) -> String {
        let mutable = NSMutableString(string: text)
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        return mutable as String
    }

    private struct KeyMapping {
        let keyCode: CGKeyCode
        let shift: Bool
    }

    // US keyboard layout virtual keycodes
    private static let asciiKeycodeMap: [Character: KeyMapping] = {
        var map: [Character: KeyMapping] = [:]

        let lowercase: [(Character, CGKeyCode)] = [
            ("a", 0x00), ("b", 0x0B), ("c", 0x08), ("d", 0x02), ("e", 0x0E),
            ("f", 0x03), ("g", 0x05), ("h", 0x04), ("i", 0x22), ("j", 0x26),
            ("k", 0x28), ("l", 0x25), ("m", 0x2E), ("n", 0x2D), ("o", 0x1F),
            ("p", 0x23), ("q", 0x0C), ("r", 0x0F), ("s", 0x01), ("t", 0x11),
            ("u", 0x20), ("v", 0x09), ("w", 0x0D), ("x", 0x07), ("y", 0x10),
            ("z", 0x06),
        ]
        for (ch, kc) in lowercase {
            map[ch] = KeyMapping(keyCode: kc, shift: false)
            map[Character(ch.uppercased())] = KeyMapping(keyCode: kc, shift: true)
        }

        let digits: [(Character, CGKeyCode)] = [
            ("0", 0x1D), ("1", 0x12), ("2", 0x13), ("3", 0x14), ("4", 0x15),
            ("5", 0x17), ("6", 0x16), ("7", 0x1A), ("8", 0x1C), ("9", 0x19),
        ]
        for (ch, kc) in digits {
            map[ch] = KeyMapping(keyCode: kc, shift: false)
        }

        let shifted: [(Character, CGKeyCode)] = [
            ("!", 0x12), ("@", 0x13), ("#", 0x14), ("$", 0x15), ("%", 0x17),
            ("^", 0x16), ("&", 0x1A), ("*", 0x1C), ("(", 0x19), (")", 0x1D),
        ]
        for (ch, kc) in shifted {
            map[ch] = KeyMapping(keyCode: kc, shift: true)
        }

        let punctuation: [(Character, CGKeyCode, Bool)] = [
            (" ",  0x31, false), ("\t", 0x30, false), ("\n", 0x24, false),
            ("-",  0x1B, false), ("_",  0x1B, true),
            ("=",  0x18, false), ("+",  0x18, true),
            ("[",  0x21, false), ("{",  0x21, true),
            ("]",  0x1E, false), ("}",  0x1E, true),
            ("\\", 0x2A, false), ("|",  0x2A, true),
            (";",  0x29, false), (":",  0x29, true),
            ("'",  0x27, false), ("\"", 0x27, true),
            (",",  0x2B, false), ("<",  0x2B, true),
            (".",  0x2F, false), (">",  0x2F, true),
            ("/",  0x2C, false), ("?",  0x2C, true),
            ("`",  0x32, false), ("~",  0x32, true),
        ]
        for (ch, kc, sh) in punctuation {
            map[ch] = KeyMapping(keyCode: kc, shift: sh)
        }

        return map
    }()

    // MARK: - Helpers

    private static func activateTargetApplication(processIdentifier: pid_t?) {
        guard let processIdentifier,
              let application = NSRunningApplication(processIdentifier: processIdentifier),
              !application.isTerminated else {
            return
        }

        application.activate(options: [])
        usleep(200_000)
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
