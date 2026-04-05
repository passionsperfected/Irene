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

    private var timer: Timer?
    private var startTime: Date?
    private var outputURL: URL?

    // Mic recording
    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private(set) var micTempURL: URL?

    #if os(macOS)
    // System audio recording
    private var scStream: SCStream?
    private var streamOutput: AudioStreamOutput?
    private var assetWriter: AVAssetWriter?
    private var audioInput: AVAssetWriterInput?
    private let captureQueue = DispatchQueue(label: "com.irene.audiocapture", qos: .userInitiated)
    private var systemTempURL: URL?
    #endif

    var canCaptureSystemAudio: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }

    func startRecording(to url: URL, source: AudioSource) async throws {
        outputURL = url

        switch source {
        case .micOnly:
            try await startMicRecording(to: url)
        case .systemAndMic:
            #if os(macOS)
            try await startDualRecording(finalURL: url)
            #else
            try await startMicRecording(to: url)
            #endif
        }

        isRecording = true
        startTime = Date()
        startTimer()
    }

    func stopRecording() -> (url: URL?, duration: TimeInterval) {
        stopTimer()
        stopLevelMetering()
        let duration = elapsedTime
        let finalURL = outputURL

        // Stop mic recorder
        audioRecorder?.stop()
        audioRecorder = nil

        #if os(macOS)
        // Stop system audio stream
        if let stream = scStream {
            let s = stream
            Task { try? await s.stopCapture() }
            scStream = nil
        }

        // Finalize system audio writer
        if let input = audioInput { input.markAsFinished() }
        if let writer = assetWriter, writer.status == .writing {
            let w = writer
            let micURL = micTempURL
            let sysURL = systemTempURL
            let outURL = finalURL

            w.finishWriting {
                // Merge after writer finishes
                if let micURL, let sysURL, let outURL {
                    Task { @MainActor in
                        await Self.mergeAudioFiles(micURL: micURL, systemURL: sysURL, outputURL: outURL)
                    }
                }
            }
        } else if let micURL = micTempURL, let outURL = finalURL {
            // No system audio — just move mic file to output
            try? FileManager.default.moveItem(at: micURL, to: outURL)
        }

        assetWriter = nil
        audioInput = nil
        streamOutput = nil
        #endif

        isRecording = false
        let elapsed = elapsedTime
        elapsedTime = 0
        audioLevel = 0

        print("[IRENE Audio] Recording stopped, duration: \(elapsed)s")
        return (finalURL, elapsed)
    }

    // MARK: - Mic Only

    private func startMicRecording(to url: URL) async throws {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        guard granted else { throw IRENEError.permissionDenied("Microphone access denied") }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.delegate = self
        guard recorder.record() else { throw IRENEError.permissionDenied("Failed to start recording") }

        audioRecorder = recorder
        startLevelMetering()
        print("[IRENE Audio] Mic-only recording started to: \(url.lastPathComponent)")
    }

    // MARK: - Dual Recording (System + Mic simultaneously)

    #if os(macOS)
    private func startDualRecording(finalURL: URL) async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let sessionID = UUID().uuidString

        // Temp files for mic and system audio
        let micURL = tempDir.appendingPathComponent("irene_mic_\(sessionID).m4a")
        let sysURL = tempDir.appendingPathComponent("irene_sys_\(sessionID).m4a")
        micTempURL = micURL
        systemTempURL = sysURL

        // Start mic recording to temp file
        let micGranted = await AVCaptureDevice.requestAccess(for: .audio)
        guard micGranted else { throw IRENEError.permissionDenied("Microphone access denied") }

        let micSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: micURL, settings: micSettings)
        recorder.isMeteringEnabled = true
        recorder.delegate = self
        guard recorder.record() else { throw IRENEError.permissionDenied("Failed to start mic recording") }
        audioRecorder = recorder

        print("[IRENE Audio] Mic recording started to: \(micURL.lastPathComponent)")

        // Start system audio capture to temp file
        let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = availableContent.displays.first else {
            throw IRENEError.permissionDenied("No display found for system audio capture")
        }

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.showsCursor = false

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)

        let writer = try AVAssetWriter(outputURL: sysURL, fileType: .m4a)
        let audioSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 48000.0,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000
        ]

        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        input.expectsMediaDataInRealTime = true
        writer.add(input)

        let output = AudioStreamOutput(assetWriterInput: input, assetWriter: writer)
        try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: captureQueue)

        writer.startWriting()
        // Don't start session here — AudioStreamOutput starts it with the first buffer's timestamp
        try await stream.startCapture()

        scStream = stream
        streamOutput = output
        assetWriter = writer
        audioInput = input

        startLevelMetering()
        print("[IRENE Audio] System audio recording started to: \(sysURL.lastPathComponent)")
        print("[IRENE Audio] Dual recording active — mic + system")
    }

    // MARK: - Merge Audio Files

    static func mergeAudioFiles(micURL: URL, systemURL: URL, outputURL: URL) async {
        print("[IRENE Audio] Merging mic + system audio via PCM mixdown...")

        let targetSampleRate: Double = 44100
        let targetChannels: UInt32 = 1 // Mono — best for speech recognition

        do {
            // Read PCM samples from mic file
            let micSamples = try await readPCMSamples(from: micURL, targetSampleRate: targetSampleRate)
            print("[IRENE Audio] Mic samples: \(micSamples.count)")

            // Read PCM samples from system file
            let sysSamples = try await readPCMSamples(from: systemURL, targetSampleRate: targetSampleRate)
            let sysMax = sysSamples.max() ?? 0
            let sysRMS = sqrt(sysSamples.reduce(0) { $0 + $1 * $1 } / Float(max(sysSamples.count, 1)))
            print("[IRENE Audio] System samples: \(sysSamples.count), max: \(sysMax), RMS: \(sysRMS)")

            // Mix: add samples together, clamping to prevent clipping
            let maxLength = max(micSamples.count, sysSamples.count)
            var mixed = [Float](repeating: 0, count: maxLength)

            for i in 0..<maxLength {
                let mic: Float = i < micSamples.count ? micSamples[i] * 1.0 : 0
                let sys: Float = i < sysSamples.count ? sysSamples[i] * 0.8 : 0
                mixed[i] = max(-1.0, min(1.0, mic + sys))
            }

            print("[IRENE Audio] Mixed samples: \(mixed.count)")

            // Write mixed PCM to output file as AAC
            try writePCMToAAC(samples: mixed, sampleRate: targetSampleRate, to: outputURL)

            print("[IRENE Audio] Merge complete: \(outputURL.lastPathComponent)")

            // Keep temp files for debugging — copy to audio dir
            if let audioDir = outputURL.deletingLastPathComponent() as URL? {
                let debugMic = audioDir.appendingPathComponent("debug_mic.m4a")
                let debugSys = audioDir.appendingPathComponent("debug_sys.m4a")
                try? FileManager.default.removeItem(at: debugMic)
                try? FileManager.default.removeItem(at: debugSys)
                try? FileManager.default.copyItem(at: micURL, to: debugMic)
                try? FileManager.default.copyItem(at: systemURL, to: debugSys)
                print("[IRENE Audio] Debug files saved: debug_mic.m4a, debug_sys.m4a")
            }

            try? FileManager.default.removeItem(at: micURL)
            try? FileManager.default.removeItem(at: systemURL)

        } catch {
            print("[IRENE Audio] Merge error: \(error)")
            // Fallback: copy mic file
            try? FileManager.default.copyItem(at: micURL, to: outputURL)
        }
    }

    /// Read audio file and return mono Float32 PCM samples at the target sample rate
    private static func readPCMSamples(from url: URL, targetSampleRate: Double) async throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = AVAudioFormat(standardFormatWithSampleRate: targetSampleRate, channels: 1)!

        guard let converter = AVAudioConverter(from: file.processingFormat, to: format) else {
            throw IRENEError.serializationFailed("Cannot create audio converter")
        }

        let frameCapacity = AVAudioFrameCount(file.length)
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCapacity) else {
            throw IRENEError.serializationFailed("Cannot create input buffer")
        }
        try file.read(into: inputBuffer)

        let outputFrameCapacity = AVAudioFrameCount(Double(frameCapacity) * targetSampleRate / file.processingFormat.sampleRate)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: outputFrameCapacity + 1024) else {
            throw IRENEError.serializationFailed("Cannot create output buffer")
        }

        var gotData = false
        try converter.convert(to: outputBuffer, error: nil) { _, outStatus in
            if !gotData {
                gotData = true
                outStatus.pointee = .haveData
                return inputBuffer
            } else {
                outStatus.pointee = .endOfStream
                return nil
            }
        }

        guard let channelData = outputBuffer.floatChannelData?[0] else {
            throw IRENEError.serializationFailed("No channel data")
        }

        return Array(UnsafeBufferPointer(start: channelData, count: Int(outputBuffer.frameLength)))
    }

    /// Write Float32 PCM samples to an AAC M4A file
    private static func writePCMToAAC(samples: [Float], sampleRate: Double, to url: URL) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        let file = try AVAudioFile(
            forWriting: url,
            settings: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
        )

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)

        memcpy(buffer.floatChannelData![0], samples, samples.count * MemoryLayout<Float>.size)

        try file.write(from: buffer)
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

    private func startLevelMetering() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let recorder = self.audioRecorder else { return }
                recorder.updateMeters()
                let level = recorder.averagePower(forChannel: 0)
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
            Task { @MainActor in self.isRecording = false }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in self.isRecording = false }
    }
}

// MARK: - ScreenCaptureKit Audio Stream Output

#if os(macOS)
class AudioStreamOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    private let assetWriterInput: AVAssetWriterInput
    private let assetWriter: AVAssetWriter
    private var hasStartedSession = false

    init(assetWriterInput: AVAssetWriterInput, assetWriter: AVAssetWriter) {
        self.assetWriterInput = assetWriterInput
        self.assetWriter = assetWriter
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid, assetWriter.status == .writing else { return }

        if !hasStartedSession {
            assetWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            hasStartedSession = true
        }

        if assetWriterInput.isReadyForMoreMediaData {
            assetWriterInput.append(sampleBuffer)
        }
    }
}
#endif
