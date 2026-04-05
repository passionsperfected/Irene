import Foundation
import Speech

@MainActor @Observable
final class RecordingViewModel {
    private(set) var sessions: [RecordingSession] = []
    private(set) var isLoading = false
    var errorMessage: String?

    let captureService = AudioCaptureService()
    let transcriptionService = TranscriptionService()
    var activeSession: RecordingSession?

    private let vaultManager: VaultManager
    private let llmService: LLMService?
    private let storage = JSONStorage<RecordingSession>()

    init(vaultManager: VaultManager, llmService: LLMService? = nil) {
        self.vaultManager = vaultManager
        self.llmService = llmService
    }

    func loadSessions() async {
        guard let dir = try? vaultManager.directoryURL(for: .recording) else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            sessions = try await storage.loadAll(in: dir)
                .sorted { $0.startTime > $1.startTime }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startRecording(source: AudioSource, title: String) async {
        var session = RecordingSession(title: title, audioSource: source)
        let audioFileName = "\(session.id).m4a"
        session.audioFileName = audioFileName

        do {
            let audioDir = try vaultManager.url(for: "recording/audio")
            let audioURL = audioDir.appendingPathComponent(audioFileName)

            try await captureService.startRecording(to: audioURL, source: source)
            activeSession = session
            sessions.insert(session, at: 0)
            try await saveSession(session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopRecording() async {
        guard var session = activeSession else { return }

        let result = captureService.stopRecording()
        session.endTime = Date()
        session.duration = result.duration
        session.status = .complete

        // For virtual meetings, save reference to the mic-only temp file for transcription
        if session.audioSource == .systemAndMic, let micURL = captureService.micTempURL {
            let micFileName = "\(session.id)_mic.m4a"
            if let audioDir = try? vaultManager.url(for: "recording/audio") {
                let destURL = audioDir.appendingPathComponent(micFileName)
                let exists = FileManager.default.fileExists(atPath: micURL.path)
                let size = (try? FileManager.default.attributesOfItem(atPath: micURL.path)[.size] as? Int) ?? 0
                print("[IRENE Recording] Mic temp file exists: \(exists), size: \(size), path: \(micURL.path)")

                do {
                    try FileManager.default.copyItem(at: micURL, to: destURL)
                    session.micOnlyFileName = micFileName
                    print("[IRENE Recording] Copied mic file to: \(destURL.lastPathComponent)")
                } catch {
                    print("[IRENE Recording] Failed to copy mic file: \(error)")
                }
            }
        }

        activeSession = nil

        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
        try? await saveSession(session)
    }

    func transcribeSession(_ session: RecordingSession) async {
        guard let audioFileName = session.audioFileName else {
            errorMessage = "No audio file name"
            return
        }

        // Ensure speech recognition permission
        await transcriptionService.requestAuthorizationIfNeeded()
        guard transcriptionService.isAuthorized else {
            errorMessage = "Speech recognition permission denied. Enable it in System Settings > Privacy & Security > Speech Recognition."
            return
        }

        guard let audioDir = try? vaultManager.url(for: "recording/audio") else {
            errorMessage = "Cannot find audio directory"
            return
        }

        // Always transcribe the main merged audio file (has both mic + system audio)
        let audioURL = audioDir.appendingPathComponent(audioFileName)
        print("[IRENE Recording] Transcribing main audio: \(audioFileName)")

        // Check file exists and has content
        let fileExists = FileManager.default.fileExists(atPath: audioURL.path)
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? Int) ?? 0
        print("[IRENE Recording] Transcribing: \(audioURL.path)")
        print("[IRENE Recording] File exists: \(fileExists), size: \(fileSize) bytes")

        guard fileExists && fileSize > 0 else {
            errorMessage = "Audio file is missing or empty. The recording may have failed — check microphone permissions in System Settings."
            updateSessionStatus(session.id, status: .failed)
            return
        }

        updateSessionStatus(session.id, status: .transcribing)

        do {
            var transcription = try await transcriptionService.transcribe(audioURL: audioURL)
            transcription = Transcription(
                recordingId: session.id,
                segments: transcription.segments,
                fullText: transcription.fullText
            )

            // Save transcription
            let transcriptionDir = try vaultManager.url(for: "recording/transcription")
            let transcriptionURL = transcriptionDir.appendingPathComponent("\(session.id).json")
            let transcriptionStorage = JSONStorage<Transcription>()
            try await transcriptionStorage.save(transcription, to: transcriptionURL)

            // Update session
            if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[index].transcriptionFileName = "\(session.id).json"
                sessions[index].status = .complete
                try? await saveSession(sessions[index])
            }
        } catch {
            errorMessage = error.localizedDescription
            updateSessionStatus(session.id, status: .failed)
        }
    }

    func summarizeSession(_ session: RecordingSession) async {
        guard let llmService else {
            errorMessage = "LLM service not configured. Add an API key in Settings."
            print("[IRENE Recording] Summarize failed: llmService is nil")
            return
        }
        guard let transcriptionFileName = session.transcriptionFileName else {
            errorMessage = "No transcription found. Transcribe the recording first."
            print("[IRENE Recording] Summarize failed: no transcription file")
            return
        }
        guard llmService.isConfigured else {
            errorMessage = "LLM not configured. Add an API key in Settings."
            print("[IRENE Recording] Summarize failed: LLM not configured")
            return
        }

        do {
            let transcriptionDir = try vaultManager.url(for: "recording/transcription")
            let transcriptionURL = transcriptionDir.appendingPathComponent(transcriptionFileName)
            let transcriptionStorage = JSONStorage<Transcription>()
            let transcription = try await transcriptionStorage.load(from: transcriptionURL)

            updateSessionStatus(session.id, status: .summarizing)

            let prompt = """
            Summarize this meeting transcript. Include:
            1. A brief overall summary (2-3 sentences)
            2. Key topics discussed
            3. Action items identified
            4. Any follow-up needed

            Transcript:
            \(transcription.fullText)
            """

            var summaryText = ""
            let stream = llmService.send(
                messages: [.user(prompt)],
                systemPrompt: "You are a meeting summarization assistant. Be concise and structured.",
                maxTokens: 2048
            )

            for try await chunk in stream {
                summaryText += chunk.text
                if chunk.isComplete { break }
            }

            let summary = RecordingSummary(
                recordingId: session.id,
                summary: summaryText,
                keyTopics: extractKeyTopics(from: summaryText),
                actionItems: extractActionItems(from: summaryText),
                generatedAt: Date(),
                model: llmService.selectedModel.id
            )

            let summaryDir = try vaultManager.url(for: "recording/summary")
            let summaryURL = summaryDir.appendingPathComponent("\(session.id).json")
            let summaryStorage = JSONStorage<RecordingSummary>()
            try await summaryStorage.save(summary, to: summaryURL)

            if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[index].summaryFileName = "\(session.id).json"
                sessions[index].status = .complete
                try? await saveSession(sessions[index])
            }
        } catch {
            errorMessage = error.localizedDescription
            updateSessionStatus(session.id, status: .failed)
        }
    }

    func deleteSession(_ session: RecordingSession) async {
        do {
            let dir = try vaultManager.directoryURL(for: .recording)
            let fileURL = dir.appendingPathComponent(session.fileName)
            try await storage.delete(at: fileURL)

            // Clean up associated files
            if let audioFileName = session.audioFileName {
                let audioURL = try vaultManager.url(for: "recording/audio/\(audioFileName)")
                try? FileManager.default.removeItem(at: audioURL)
            }
            if let transcriptionFileName = session.transcriptionFileName {
                let url = try vaultManager.url(for: "recording/transcription/\(transcriptionFileName)")
                try? FileManager.default.removeItem(at: url)
            }
            if let summaryFileName = session.summaryFileName {
                let url = try vaultManager.url(for: "recording/summary/\(summaryFileName)")
                try? FileManager.default.removeItem(at: url)
            }

            sessions.removeAll { $0.id == session.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func saveSession(_ session: RecordingSession) async throws {
        let dir = try vaultManager.directoryURL(for: .recording)
        let fileURL = dir.appendingPathComponent(session.fileName)
        try await storage.save(session, to: fileURL)
    }

    private func updateSessionStatus(_ id: UUID, status: RecordingStatus) {
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            sessions[index].status = status
        }
    }

    private func extractKeyTopics(from text: String) -> [String] {
        // Simple extraction: look for numbered or bulleted items after "Key topics" or "Topics"
        let lines = text.components(separatedBy: .newlines)
        var topics: [String] = []
        var inTopicsSection = false

        for line in lines {
            let lower = line.lowercased()
            if lower.contains("key topic") || lower.contains("topics discussed") {
                inTopicsSection = true
                continue
            }
            if inTopicsSection {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.lowercased().contains("action") { break }
                let cleaned = trimmed
                    .replacingOccurrences(of: "^[\\d\\-\\*\\.\\)]+\\s*", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty { topics.append(cleaned) }
            }
        }
        return topics
    }

    private func extractActionItems(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var items: [String] = []
        var inActionSection = false

        for line in lines {
            let lower = line.lowercased()
            if lower.contains("action item") {
                inActionSection = true
                continue
            }
            if inActionSection {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || (trimmed.lowercased().contains("follow") && !trimmed.hasPrefix("-")) { break }
                let cleaned = trimmed
                    .replacingOccurrences(of: "^[\\d\\-\\*\\.\\)]+\\s*", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty { items.append(cleaned) }
            }
        }
        return items
    }
}
