import AppKit
import SwiftUI

@main
struct WhisperAutomatorApp: App {
    @StateObject private var dictationController = DictationController()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("Whisper Automator", id: "main") {
            ContentView(controller: dictationController)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
        }

        MenuBarExtra("Whisper Automator", systemImage: dictationController.menuBarIcon) {
            Label(dictationController.statusText, systemImage: dictationController.menuBarIcon)

            Divider()

            Button(dictationController.isRecording ? "Stop & Transcribe" : "Start Dictation") {
                if dictationController.isRecording {
                    dictationController.stopRecordingAndTranscribe(insertIntoFocusedApp: true)
                } else {
                    dictationController.beginHoldToTalk()
                }
            }
            .disabled(dictationController.isTranscribing)

            Button("Open App") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }

            SettingsLink {
                Text("Settings...")
            }

            Divider()

            Button("Quit Whisper Automator") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
