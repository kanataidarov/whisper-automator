import AppKit
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
    private var activationObserver: NSObjectProtocol?
    private var lastFocusedApplicationPID: pid_t?
    private var pendingInsertionTargetPID: pid_t?

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
        observeFocusedApplications()
        setupHotkeys()
    }

    // MARK: - Public actions

    func beginHoldToTalk(insertIntoFocusedApp: Bool = false) {
        guard state != .recording, state != .transcribing else { return }
        pendingInsertionTargetPID = insertIntoFocusedApp ? currentInsertionTargetPID() : nil
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
        let insertionTargetPID = insertIntoFocusedApp
            ? pendingInsertionTargetPID ?? currentInsertionTargetPID()
            : nil
        pendingInsertionTargetPID = nil
        recorder.stopRecording()
        logger.info("Recording stopped, file at \(url.path)")
        transcribe(
            fileURL: url,
            insertIntoFocusedApp: insertIntoFocusedApp,
            insertionTargetPID: insertionTargetPID
        )
    }

    func toggleRecording(insertIntoFocusedApp: Bool = false) {
        if recorder.isRecording {
            stopRecordingAndTranscribe(insertIntoFocusedApp: insertIntoFocusedApp)
        } else {
            beginHoldToTalk(insertIntoFocusedApp: insertIntoFocusedApp)
        }
    }

    // MARK: - Private

    private func observeRecorder() {
        recorder.$state
            .sink { [weak self] recorderState in
                if case .failed(let msg) = recorderState {
                    self?.state = .error(msg)
                    self?.pendingInsertionTargetPID = nil
                }
            }
            .store(in: &cancellables)
    }

    private func observeFocusedApplications() {
        if let frontmostApplication = NSWorkspace.shared.frontmostApplication {
            rememberFocusedApplication(
                processIdentifier: frontmostApplication.processIdentifier,
                bundleIdentifier: frontmostApplication.bundleIdentifier
            )
        }

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication
            else {
                return
            }

            let processIdentifier = application.processIdentifier
            let bundleIdentifier = application.bundleIdentifier

            Task { @MainActor [weak self] in
                self?.rememberFocusedApplication(
                    processIdentifier: processIdentifier,
                    bundleIdentifier: bundleIdentifier
                )
            }
        }
    }

    private func rememberFocusedApplication(processIdentifier: pid_t, bundleIdentifier: String?) {
        guard processIdentifier != NSRunningApplication.current.processIdentifier else { return }
        guard bundleIdentifier != Bundle.main.bundleIdentifier else { return }

        lastFocusedApplicationPID = processIdentifier
    }

    private func currentInsertionTargetPID() -> pid_t? {
        if let frontmostApplication = NSWorkspace.shared.frontmostApplication,
           frontmostApplication.processIdentifier != NSRunningApplication.current.processIdentifier,
           frontmostApplication.bundleIdentifier != Bundle.main.bundleIdentifier {
            return frontmostApplication.processIdentifier
        }

        return lastFocusedApplicationPID
    }

    nonisolated private func setupHotkeys() {
        KeyboardShortcuts.onKeyDown(for: .holdToTalk) { [weak self] in
            Task { @MainActor in
                self?.beginHoldToTalk(insertIntoFocusedApp: true)
            }
        }
        KeyboardShortcuts.onKeyUp(for: .holdToTalk) { [weak self] in
            Task { @MainActor in
                self?.endHoldToTalkAndTranscribe()
            }
        }
    }

    private func transcribe(
        fileURL: URL,
        insertIntoFocusedApp: Bool,
        insertionTargetPID: pid_t?
    ) {
        state = .transcribing
        logger.info(
            "Transcribing \(fileURL.lastPathComponent) and translating to: \(self.selectedLanguage.rawValue)"
        )

        Task {
            do {
                let text = try await WhisperClient.transcribeAndTranslate(
                    fileURL: fileURL,
                    targetLanguage: selectedLanguage
                )
                logger.info("Transcription succeeded: \(text.prefix(80))…")
                state = .success(text)
                if insertIntoFocusedApp {
                    Task.detached {
                        usleep(150_000) // 150 ms – let the previously-focused app stabilise
                        TextInsertionService.insert(
                            text,
                            targetProcessIdentifier: insertionTargetPID
                        )
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
