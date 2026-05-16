import AVFoundation
import Foundation

@MainActor
final class AudioRecorder: ObservableObject {
    enum State: Equatable, Sendable {
        case idle
        case recording
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var recordingURL: URL?

    private var recorder: AVAudioRecorder?

    var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    func startRecording() {
        let permission = AVCaptureDevice.authorizationStatus(for: .audio)

        switch permission {
        case .authorized:
            beginRecording()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        self?.beginRecording()
                    } else {
                        self?.state = .failed("Microphone access denied.")
                    }
                }
            }
        default:
            state = .failed("Microphone access denied. Enable it in System Settings > Privacy & Security > Microphone.")
        }
    }

    func stopRecording() {
        recorder?.stop()
        recorder = nil
        state = .idle
    }

    private func beginRecording() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("whisper_recording_\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder.prepareToRecord()

            guard audioRecorder.record() else {
                state = .failed("Failed to start recording.")
                return
            }

            recorder = audioRecorder
            recordingURL = fileURL
            state = .recording
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
