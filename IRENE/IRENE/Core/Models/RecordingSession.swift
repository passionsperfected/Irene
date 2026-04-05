import Foundation

enum RecordingStatus: String, Codable, Sendable {
    case recording
    case transcribing
    case summarizing
    case complete
    case failed
}

enum AudioSource: String, Codable, CaseIterable, Sendable {
    case systemAndMic = "Virtual Meeting"
    case micOnly = "In-Person Meeting"
}

struct RecordingSession: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var title: String
    var startTime: Date
    var endTime: Date?
    var duration: TimeInterval?
    var audioFileName: String?
    var micOnlyFileName: String?  // Separate mic-only file for better transcription
    var transcriptionFileName: String?
    var summaryFileName: String?
    var status: RecordingStatus
    var audioSource: AudioSource
    var tags: [String]

    init(
        id: UUID = UUID(),
        title: String = "Recording",
        startTime: Date = Date(),
        endTime: Date? = nil,
        duration: TimeInterval? = nil,
        audioFileName: String? = nil,
        transcriptionFileName: String? = nil,
        summaryFileName: String? = nil,
        status: RecordingStatus = .recording,
        audioSource: AudioSource = .micOnly,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.audioFileName = audioFileName
        self.transcriptionFileName = transcriptionFileName
        self.summaryFileName = summaryFileName
        self.status = status
        self.audioSource = audioSource
        self.tags = tags
    }

    var fileName: String { "\(id).json" }

    var durationFormatted: String {
        guard let duration else { return "0:00" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func toMetadata() -> ItemMetadata {
        ItemMetadata(
            id: id,
            created: startTime,
            modified: endTime ?? startTime,
            tags: tags,
            moduleType: .recording,
            title: title,
            summary: "Duration: \(durationFormatted) | Status: \(status.rawValue)"
        )
    }
}

struct Transcription: Codable, Sendable {
    let recordingId: UUID
    var segments: [TranscriptionSegment]
    var fullText: String
}

struct TranscriptionSegment: Codable, Sendable {
    let timestamp: TimeInterval
    let duration: TimeInterval
    let text: String
    let confidence: Float
}

struct RecordingSummary: Codable, Sendable {
    let recordingId: UUID
    var summary: String
    var keyTopics: [String]
    var actionItems: [String]
    var generatedAt: Date
    var model: String
}
