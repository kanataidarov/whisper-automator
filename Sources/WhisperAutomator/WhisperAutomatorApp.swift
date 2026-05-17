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

        MenuBarExtra {
            Label {
                Text(dictationController.statusText)
            } icon: {
                Image(nsImage: dictationController.menuBarIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 18, height: 18)
            }

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
        } label: {
            Image(nsImage: dictationController.menuBarIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 18, height: 18)
                .accessibilityLabel("Whisper Automator")
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
