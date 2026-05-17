import ApplicationServices
@preconcurrency import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var showKey = false
    @State private var saveStatus: String?
    @AppStorage("defaultLanguage") private var defaultLanguage: String = TranscriptionLanguage.russian.rawValue

    var body: some View {
        Form {
            Section("OpenAI API Key") {
                HStack {
                    if showKey {
                        TextField("sk-...", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("sk-...", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    Button(showKey ? "Hide" : "Show") {
                        showKey.toggle()
                    }
                    .buttonStyle(.borderless)
                }

                HStack {
                    Button("Save Key") {
                        do {
                            try KeychainStore.saveAPIKey(apiKey)
                            saveStatus = "Saved successfully"
                        } catch {
                            saveStatus = error.localizedDescription
                        }
                    }
                    .disabled(apiKey.isEmpty)

                    Button("Delete Key") {
                        KeychainStore.deleteAPIKey()
                        apiKey = ""
                        saveStatus = "Key deleted"
                    }
                    .foregroundColor(.red)

                    if let status = saveStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Default Language") {
                Picker("Language", selection: $defaultLanguage) {
                    ForEach(TranscriptionLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Dictation Shortcut") {
                KeyboardShortcuts.Recorder("Hold to dictate:", name: .holdToTalk)

                Text("Hold this shortcut while speaking. Release it to transcribe and paste the text into the currently focused input field.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Text Insertion Permission") {
                HStack {
                    Text(AXIsProcessTrusted() ? "Accessibility access granted" : "Accessibility access required")
                        .foregroundColor(AXIsProcessTrusted() ? .secondary : .orange)

                    Spacer()

                    Button("Request Access") {
                        requestAccessibilityAccess()
                    }
                }

                Text("Accessibility access lets WhisperAutomator paste dictated text into other apps and text fields.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 460)
        .onAppear {
            apiKey = KeychainStore.loadAPIKey() ?? ""
        }
    }

    private func requestAccessibilityAccess() {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
