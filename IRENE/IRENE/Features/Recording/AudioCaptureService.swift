import Foundation
import AVFoundation

#if os(macOS)
import ScreenCaptureKit
#endif

@MainActor @Observable
final class AudioCaptureService: NSObject, @unchecked Sendable {
    private(set) var isRecording = false
    private(set) var audioLevel: Float = 0
    private(set) var elapsedTime: TimeInterval = 0

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var startTime: Date?
    private var levelTimer: Timer?

    var canCaptureSystemAudio: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }

    func startRecording(to url: URL, source: AudioSource) async throws {
        // Request microphone permission
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        guard granted else {
            throw IRENEError.permissionDenied("Microphone access denied")
        }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        print("[IRENE Audio] Starting recording to: \(url.path)")

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.delegate = self

        guard recorder.record() else {
            throw IRENEError.permissionDenied("Failed to start recording")
        }

        audioRecorder = recorder
        isRecording = true
        startTime = Date()
        startTimer()
        startLevelMetering()

        print("[IRENE Audio] Recording started successfully")
    }

    func stopRecording() -> (url: URL?, duration: TimeInterval) {
        stopTimer()
        stopLevelMetering()

        let duration = elapsedTime
        let url = audioRecorder?.url

        audioRecorder?.stop()
        audioRecorder = nil

        isRecording = false
        let elapsed = elapsedTime
        elapsedTime = 0
        audioLevel = 0

        print("[IRENE Audio] Recording stopped, duration: \(elapsed)s")

        return (url, elapsed)
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let startTime = self.startTime else { return }
                self.elapsedTime = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Audio Level Metering

    private func startLevelMetering() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let recorder = self.audioRecorder else { return }
                recorder.updateMeters()
                let level = recorder.averagePower(forChannel: 0)
                // Convert dB to linear (0-1 range)
                self.audioLevel = max(0, min(1, (level + 50) / 50))
            }
        }
    }

    private func stopLevelMetering() {
        levelTimer?.invalidate()
        levelTimer = nil
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioCaptureService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            Task { @MainActor in
                self.isRecording = false
                print("[IRENE Audio] Recording finished unsuccessfully")
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            self.isRecording = false
            print("[IRENE Audio] Recording encode error: \(error?.localizedDescription ?? "unknown")")
        }
    }
}
