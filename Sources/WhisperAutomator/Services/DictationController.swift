import Combine
@preconcurrency import KeyboardShortcuts
import os.log
import SwiftUI

private let logger = Logger(subsystem: "WhisperAutomator", category: "Dictation")

@MainActor
final class DictationController: ObservableObject {
    enum DictationState: Equatable, Sendable {
        case idle
        case recording
        case transcribing
        case success(String)
        case error(String)
    }

    @Published private(set) var state: DictationState = .idle

    let recorder = AudioRecorder()
    private var cancellables = Set<AnyCancellable>()

    var isRecording: Bool {
        state == .recording
    }

    var isTranscribing: Bool {
        state == .transcribing
    }

    private var selectedLanguage: TranscriptionLanguage {
        let raw = UserDefaults.standard.string(forKey: "defaultLanguage")
            ?? TranscriptionLanguage.russian.rawValue
        return TranscriptionLanguage(rawValue: raw) ?? .russian
    }

    var menuBarIcon: String {
        switch state {
        case .idle, .success, .error: "mic"
        case .recording: "mic.fill"
        case .transcribing: "ellipsis.circle"
        }
    }

    var statusText: String {
        switch state {
        case .idle: "Ready"
        case .recording: "Recording…"
        case .transcribing: "Transcribing…"
        case .success: "Done"
        case .error(let msg): "Error: \(msg)"
        }
    }

    init() {
        observeRecorder()
        setupHotkeys()
    }

    // MARK: - Public actions

    func beginHoldToTalk() {
        guard state != .recording, state != .transcribing else { return }
        logger.info("Hold-to-talk: recording started")
        state = .recording
        recorder.startRecording()
    }

    func endHoldToTalkAndTranscribe() {
        stopRecordingAndTranscribe(insertIntoFocusedApp: true)
    }

    func stopRecordingAndTranscribe(insertIntoFocusedApp: Bool) {
        guard recorder.isRecording, let url = recorder.recordingURL else {
            logger.warning("stopRecordingAndTranscribe: not recording or no file URL")
            return
        }
        recorder.stopRecording()
        logger.info("Recording stopped, file at \(url.path)")
        transcribe(fileURL: url, insertIntoFocusedApp: insertIntoFocusedApp)
    }

    func toggleRecording() {
        if recorder.isRecording {
            // Capture URL before stopRecording clears it
            guard let url = recorder.recordingURL else {
                recorder.stopRecording()
                return
            }
            recorder.stopRecording()
            transcribe(fileURL: url, insertIntoFocusedApp: false)
        } else {
            state = .recording
            recorder.startRecording()
        }
    }

    // MARK: - Private

    private func observeRecorder() {
        recorder.$state
            .sink { [weak self] recorderState in
                if case .failed(let msg) = recorderState {
                    self?.state = .error(msg)
                }
            }
            .store(in: &cancellables)
    }

    nonisolated private func setupHotkeys() {
        KeyboardShortcuts.onKeyDown(for: .holdToTalk) { [weak self] in
            Task { @MainActor in
                self?.beginHoldToTalk()
            }
        }
        KeyboardShortcuts.onKeyUp(for: .holdToTalk) { [weak self] in
            Task { @MainActor in
                self?.endHoldToTalkAndTranscribe()
            }
        }
    }

    private func transcribe(fileURL: URL, insertIntoFocusedApp: Bool) {
        state = .transcribing
        logger.info("Transcribing \(fileURL.lastPathComponent), language: \(self.selectedLanguage.rawValue)")

        Task {
            do {
                let text = try await WhisperClient.transcribe(
                    fileURL: fileURL, language: selectedLanguage
                )
                logger.info("Transcription succeeded: \(text.prefix(80))…")
                state = .success(text)
                if insertIntoFocusedApp {
                    Task.detached {
                        usleep(150_000) // 150 ms – let the previously-focused app stabilise
                        TextInsertionService.insert(text)
                    }
                }
            } catch {
                logger.error("Transcription failed: \(error.localizedDescription)")
                state = .error(error.localizedDescription)
            }
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}
