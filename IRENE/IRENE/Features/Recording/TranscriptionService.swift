import Foundation
import Speech

@MainActor @Observable
final class TranscriptionService {
    private(set) var isTranscribing = false
    private(set) var progress: Double = 0
    var errorMessage: String?

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func transcribe(audioURL: URL) async throws -> Transcription {
        guard let recognizer = SFSpeechRecognizer() else {
            throw IRENEError.permissionDenied("Speech recognition not available")
        }

        guard recognizer.isAvailable else {
            throw IRENEError.permissionDenied("Speech recognizer is not available")
        }

        isTranscribing = true
        defer { isTranscribing = false }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false

        // Prefer on-device for privacy
        if #available(macOS 15.0, iOS 18.0, *) {
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        }

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { [weak self] result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let result, result.isFinal else { return }

                let segments = result.bestTranscription.segments.map { segment in
                    TranscriptionSegment(
                        timestamp: segment.timestamp,
                        duration: segment.duration,
                        text: segment.substring,
                        confidence: segment.confidence
                    )
                }

                let transcription = Transcription(
                    recordingId: UUID(), // Will be set by caller
                    segments: segments,
                    fullText: result.bestTranscription.formattedString
                )

                Task { @MainActor in
                    self?.progress = 1.0
                }

                continuation.resume(returning: transcription)
            }
        }
    }
}
