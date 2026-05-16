import SwiftUI

struct ContentView: View {
    enum TranscriptionState {
        case idle
        case recording
        case transcribing
        case success(String)
        case error(String)
    }

    @StateObject private var recorder = AudioRecorder()
    @AppStorage("defaultLanguage") private var selectedLanguageRaw: String = TranscriptionLanguage.russian.rawValue
    @State private var transcriptionState: TranscriptionState = .idle

    private var selectedLanguage: TranscriptionLanguage {
        TranscriptionLanguage(rawValue: selectedLanguageRaw) ?? .russian
    }

    var body: some View {
        VStack(spacing: 20) {
            headerSection
            languagePicker
            recordButton
            transcriptionOutput
        }
        .padding(24)
        .frame(minWidth: 460, minHeight: 380)
        .onChange(of: recorder.state) {
            if case .failed(let msg) = recorder.state {
                transcriptionState = .error(msg)
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("WhisperAutomator")
                .font(.title.bold())
            Text("Press record, speak, get text.")
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
        Button(action: toggleRecording) {
            Label(
                recorder.isRecording ? "Stop" : "Record",
                systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill"
            )
            .font(.title2)
            .foregroundColor(recorder.isRecording ? .red : .accentColor)
        }
        .buttonStyle(.plain)
        .disabled(isTranscribing)
        .keyboardShortcut(.space, modifiers: [])
    }

    @ViewBuilder
    private var transcriptionOutput: some View {
        switch transcriptionState {
        case .idle:
            EmptyView()
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

    // MARK: - Actions

    private var isTranscribing: Bool {
        if case .transcribing = transcriptionState { return true }
        return false
    }

    private func toggleRecording() {
        if recorder.isRecording {
            recorder.stopRecording()
            transcribe()
        } else {
            transcriptionState = .recording
            recorder.startRecording()
        }
    }

    private func transcribe() {
        guard let url = recorder.recordingURL else {
            transcriptionState = .error("No recording found.")
            return
        }

        transcriptionState = .transcribing

        Task {
            do {
                let text = try await WhisperClient.transcribe(fileURL: url, language: selectedLanguage)
                transcriptionState = .success(text)
            } catch {
                transcriptionState = .error(error.localizedDescription)
            }
            try? FileManager.default.removeItem(at: url)
        }
    }
}
