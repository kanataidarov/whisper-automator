import AppKit
import SwiftUI

@main
struct WhisperAutomatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var dictationController = DictationController()

    var body: some Scene {
        Settings {
            SettingsView()
        }

        MenuBarExtra("Whisper Automator", systemImage: dictationController.menuBarIcon) {
            Label(dictationController.statusText, systemImage: dictationController.menuBarIcon)

            Divider()

            Button(dictationController.isRecording ? "Stop Recording & Transcribe" : "Start Recording") {
                dictationController.toggleRecording(insertIntoFocusedApp: true)
            }
            .disabled(dictationController.isTranscribing)

            SettingsLink {
                Text("Settings…")
            }

            Divider()

            Button("Quit Whisper Automator") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
