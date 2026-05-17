import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var controller: DictationController
    @AppStorage("defaultLanguage") private var selectedLanguageRaw: String = TranscriptionLanguage.russian.rawValue

    var body: some View {
        VStack(spacing: 20) {
            headerSection
            languagePicker
            recordButton
            transcriptionOutput
        }
        .padding(24)
        .frame(minWidth: 460, minHeight: 380)
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("WhisperAutomator")
                .font(.title.bold())
            Text("Hold your configured shortcut, speak, then release to insert text.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var languagePicker: some View {
        Picker("Language", selection: $selectedLanguageRaw) {
            ForEach(TranscriptionLanguage.allCases) { lang in
                Text(lang.displayName).tag(lang.rawValue)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 300)
    }

    private var recordButton: some View {
        Button(action: controller.toggleRecording) {
            Label(
                controller.isRecording ? "Stop" : "Record",
                systemImage: controller.isRecording ? "stop.circle.fill" : "mic.circle.fill"
            )
            .font(.title2)
            .foregroundColor(controller.isRecording ? .red : .accentColor)
        }
        .buttonStyle(.plain)
        .disabled(controller.isTranscribing)
        .keyboardShortcut(.space, modifiers: [])
    }

    @ViewBuilder
    private var transcriptionOutput: some View {
        switch controller.state {
        case .idle:
            Text("Configure the dictation shortcut in Settings.")
                .font(.caption)
                .foregroundColor(.secondary)
        case .recording:
            Label("Listening...", systemImage: "waveform")
                .foregroundColor(.orange)
        case .transcribing:
            ProgressView("Transcribing...")
        case .success(let text):
            VStack(spacing: 8) {
                ScrollView {
                    Text(text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(maxHeight: 200)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(6)

                Button("Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                .buttonStyle(.borderedProminent)
            }
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        }
    }
}
