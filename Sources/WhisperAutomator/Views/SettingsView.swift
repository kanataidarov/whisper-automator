import ApplicationServices
@preconcurrency import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var showKey = false
    @State private var saveStatus: String?
    @AppStorage("defaultLanguage") private var defaultLanguage: String = TranscriptionLanguage.russian.rawValue
    @AppStorage("textInsertionMode") private var textInsertionMode: String = TextInsertionMode.paste.rawValue

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

            Section("Text Insertion Mode") {
                Picker("Mode", selection: $textInsertionMode) {
                    ForEach(TextInsertionMode.allCases) { mode in
                        VStack(alignment: .leading) {
                            Text(mode.displayName)
                            Text(mode.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(mode.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)

                Text("\"Paste (Cmd+V)\" copies to the clipboard and sends Cmd+V. \"Type ASCII\" sends US-keyboard keycodes with a short delay; use it for RDP or when paste does not work.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
        .frame(width: 540, height: 560)
        .onAppear {
            apiKey = KeychainStore.loadAPIKey() ?? ""
            if textInsertionMode == "pasteViaSystemEvents" {
                textInsertionMode = TextInsertionMode.paste.rawValue
            }
        }
    }

    private func requestAccessibilityAccess() {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
