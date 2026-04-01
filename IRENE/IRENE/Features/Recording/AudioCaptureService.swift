import Foundation
import AVFoundation

#if os(macOS)
import ScreenCaptureKit
#endif

@MainActor @Observable
final class AudioCaptureService {
    private(set) var isRecording = false
    private(set) var audioLevel: Float = 0
    private(set) var elapsedTime: TimeInterval = 0

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var timer: Timer?
    private var startTime: Date?

    #if os(macOS)
    private var scStream: SCStream?
    private var systemAudioFile: AVAudioFile?
    #endif

    var canCaptureSystemAudio: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }

    func startRecording(to url: URL, source: AudioSource) async throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)
        #endif

        switch source {
        case .micOnly:
            try startMicCapture(to: url)
        case .systemAndMic, .systemOnly:
            #if os(macOS)
            try await startSystemAndMicCapture(to: url, micEnabled: source == .systemAndMic)
            #else
            try startMicCapture(to: url)
            #endif
        }

        isRecording = true
        startTime = Date()
        startTimer()
    }

    func stopRecording() -> (url: URL?, duration: TimeInterval) {
        stopTimer()
        let duration = elapsedTime

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioFile = nil
        audioEngine = nil

        #if os(macOS)
        scStream?.stopCapture()
        scStream = nil
        systemAudioFile = nil
        #endif

        isRecording = false
        let elapsed = elapsedTime
        elapsedTime = 0
        audioLevel = 0

        return (nil, elapsed) // URL is already known by caller
    }

    // MARK: - Mic Capture

    private func startMicCapture(to url: URL) throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        audioFile = file

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            try? file.write(from: buffer)

            // Calculate audio level
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frames = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frames {
                sum += channelData[i] * channelData[i]
            }
            let rms = sqrt(sum / Float(frames))
            Task { @MainActor [weak self] in
                self?.audioLevel = rms
            }
        }

        try engine.start()
        audioEngine = engine
    }

    // MARK: - System Audio (macOS)

    #if os(macOS)
    private func startSystemAndMicCapture(to url: URL, micEnabled: Bool) async throws {
        // Start mic capture if enabled
        if micEnabled {
            try startMicCapture(to: url)
        }

        // System audio capture via ScreenCaptureKit
        let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)

        guard let display = availableContent.displays.first else {
            throw IRENEError.permissionDenied("No display found for system audio capture")
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.width = 1
        config.height = 1

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        scStream = stream

        try await stream.startCapture()
    }
    #endif

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
}
