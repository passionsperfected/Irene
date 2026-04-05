import Foundation
import Speech

@MainActor @Observable
final class TranscriptionService {
    private(set) var isTranscribing = false
    private(set) var progress: Double = 0
    var errorMessage: String?

    private var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    private let speechRecognizer = SFSpeechRecognizer()

    func requestAuthorizationIfNeeded() async {
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
        guard authorizationStatus == .notDetermined else { return }

        let status = await Self.requestAuthorizationAsync()
        self.authorizationStatus = status
    }

    // Nonisolated static helper — avoids MainActor issues with the callback
    private nonisolated static func requestAuthorizationAsync() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    var isAuthorized: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    func transcribe(audioURL: URL) async throws -> Transcription {
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw IRENEError.fileNotFound(audioURL)
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? Int) ?? 0
        print("[IRENE Transcribe] File: \(audioURL.lastPathComponent), size: \(fileSize) bytes")
        guard fileSize > 0 else {
            throw IRENEError.serializationFailed("Audio file is empty")
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw IRENEError.permissionDenied("Speech recognizer is not available")
        }

        isTranscribing = true
        defer { isTranscribing = false }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false

        if #available(macOS 15.0, iOS 18.0, *) {
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        }

        print("[IRENE Transcribe] Starting recognition...")

        // Use withCheckedThrowingContinuation — extract the String immediately
        // in the callback to avoid sending non-Sendable types across boundaries
        let transcriptText: String = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let result, result.isFinal {
                    // Extract the string immediately — don't pass the result object
                    let text = result.bestTranscription.formattedString
                    continuation.resume(returning: text)
                }
            }
        }

        print("[IRENE Transcribe] Got result: \(transcriptText.prefix(80))...")

        progress = 1.0

        // Parse into segments by splitting on sentences (simple approach)
        let segments = [TranscriptionSegment(
            timestamp: 0,
            duration: 0,
            text: transcriptText,
            confidence: 1.0
        )]

        return Transcription(
            recordingId: UUID(),
            segments: segments,
            fullText: transcriptText
        )
    }
}
