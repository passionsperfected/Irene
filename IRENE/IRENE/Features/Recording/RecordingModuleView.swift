import SwiftUI

struct RecordingModuleView: View {
    let vaultManager: VaultManager
    let llmService: LLMService

    @State private var viewModel: RecordingViewModel
    @State private var selectedSession: RecordingSession?
    @State private var loadedTranscription: Transcription?
    @State private var loadedSummary: RecordingSummary?

    @Environment(\.ireneTheme) private var theme

    init(vaultManager: VaultManager, llmService: LLMService) {
        self.vaultManager = vaultManager
        self.llmService = llmService
        self._viewModel = State(initialValue: RecordingViewModel(vaultManager: vaultManager, llmService: llmService))
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(theme.border.opacity(0.3))

            HStack(spacing: 0) {
                // Left: controls + recordings list
                VStack(spacing: 0) {
                    RecordingControlsView(viewModel: viewModel)
                        .padding(10)

                    Divider().overlay(theme.border.opacity(0.3))

                    if viewModel.sessions.isEmpty {
                        EmptyStateView(
                            icon: "waveform",
                            title: "No Recordings",
                            message: "Hit record to start"
                        )
                    } else {
                        sessionList
                    }
                }
                .frame(minWidth: 280, maxWidth: 320)

                Divider().overlay(theme.border.opacity(0.3))

                // Right: detail (transcription + summary)
                if let selectedSession {
                    sessionDetail(selectedSession)
                } else {
                    EmptyStateView(
                        icon: "waveform",
                        title: "Select a Recording",
                        message: "Choose a recording to view transcription and summary"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.background)
                }
            }
        }
        .background(theme.background)
        .task { await viewModel.loadSessions() }
    }

    private var toolbar: some View {
        HStack {
            Text("Recordings")
                .font(Typography.bodySemiBold(size: 14))
                .foregroundStyle(theme.primaryText)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var sessionList: some View {
        List(selection: $selectedSession) {
            ForEach(viewModel.sessions) { session in
                sessionRow(session)
                    .tag(session)
            }
            .onDelete { offsets in
                for offset in offsets {
                    let session = viewModel.sessions[offset]
                    Task { await viewModel.deleteSession(session) }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .onChange(of: selectedSession) { _, session in
            if let session {
                Task { await loadSessionDetails(session) }
            }
        }
    }

    private func sessionRow(_ session: RecordingSession) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(session.title)
                    .font(Typography.bodySemiBold(size: 12))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)

                Spacer()

                statusBadge(session.status)
            }

            HStack(spacing: 8) {
                Text(session.durationFormatted)
                    .font(Typography.caption(size: 10))
                    .foregroundStyle(theme.secondaryText)

                Text(session.audioSource.rawValue)
                    .font(Typography.caption(size: 9))
                    .foregroundStyle(theme.secondaryText.opacity(0.5))

                Spacer()

                Text(session.startTime, style: .relative)
                    .font(Typography.caption(size: 9))
                    .foregroundStyle(theme.secondaryText.opacity(0.5))
            }
        }
        .padding(.vertical, 3)
        .contextMenu {
            if session.transcriptionFileName == nil && session.status == .complete {
                Button("Transcribe") {
                    Task {
                        await viewModel.transcribeSession(session)
                        // Reload details after transcription completes
                        if let updated = viewModel.sessions.first(where: { $0.id == session.id }) {
                            selectedSession = updated
                            await loadSessionDetails(updated)
                        }
                    }
                }
            }
            if session.transcriptionFileName != nil && session.summaryFileName == nil {
                Button("Summarize with AI") {
                    Task {
                        await viewModel.summarizeSession(session)
                        if let updated = viewModel.sessions.first(where: { $0.id == session.id }) {
                            selectedSession = updated
                            await loadSessionDetails(updated)
                        }
                    }
                }
            }
            Divider()
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteSession(session) }
            }
        }
    }

    private func statusBadge(_ status: RecordingStatus) -> some View {
        Text(status.rawValue.capitalized)
            .font(Typography.caption(size: 8))
            .foregroundStyle(statusColor(status))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor(status).opacity(0.15))
            .clipShape(Capsule())
    }

    private func statusColor(_ status: RecordingStatus) -> Color {
        switch status {
        case .recording: return .red
        case .transcribing, .summarizing: return .orange
        case .complete: return theme.accent
        case .failed: return .red
        }
    }

    private func sessionDetail(_ session: RecordingSession) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(session.title)
                    .font(Typography.subheading(size: 18))
                    .foregroundStyle(theme.primaryText)

                HStack(spacing: 12) {
                    Label(session.durationFormatted, systemImage: "clock")
                    Label(session.audioSource.rawValue, systemImage: "waveform")
                    Label(session.startTime.formatted(), systemImage: "calendar")
                }
                .font(Typography.caption(size: 10))
                .foregroundStyle(theme.secondaryText)

                // Action buttons
                HStack(spacing: 8) {
                    if session.transcriptionFileName == nil && session.status == .complete {
                        actionButton("Transcribe", icon: "text.quote") {
                            Task {
                                await viewModel.transcribeSession(session)
                                if let updated = viewModel.sessions.first(where: { $0.id == session.id }) {
                                    selectedSession = updated
                                    await loadSessionDetails(updated)
                                }
                            }
                        }
                    }
                    if session.transcriptionFileName != nil && session.summaryFileName == nil {
                        actionButton("Summarize", icon: "brain.head.profile") {
                            Task {
                                await viewModel.summarizeSession(session)
                                if let updated = viewModel.sessions.first(where: { $0.id == session.id }) {
                                    selectedSession = updated
                                    await loadSessionDetails(updated)
                                }
                            }
                        }
                    }
                }

                if viewModel.transcriptionService.isTranscribing {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Transcribing...")
                            .font(Typography.body(size: 12))
                            .foregroundStyle(theme.secondaryText)
                    }
                }

                // Transcription
                if let transcription = loadedTranscription {
                    Divider().overlay(theme.border.opacity(0.3))
                    TranscriptionView(transcription: transcription)
                }

                // Summary
                if let summary = loadedSummary {
                    Divider().overlay(theme.border.opacity(0.3))
                    RecordingSummaryView(summary: summary) { actionItem in
                        Task {
                            let todoVM = ToDoViewModel(vaultManager: vaultManager)
                            _ = await todoVM.createItem(title: actionItem)
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }

    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(Typography.button(size: 11))
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(theme.accent.opacity(0.15))
                .foregroundStyle(theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func loadSessionDetails(_ session: RecordingSession) async {
        loadedTranscription = nil
        loadedSummary = nil

        if let transcriptionFileName = session.transcriptionFileName {
            let transcriptionStorage = JSONStorage<Transcription>()
            if let dir = try? vaultManager.url(for: "recording/transcription") {
                loadedTranscription = try? await transcriptionStorage.load(
                    from: dir.appendingPathComponent(transcriptionFileName)
                )
            }
        }

        if let summaryFileName = session.summaryFileName {
            let summaryStorage = JSONStorage<RecordingSummary>()
            if let dir = try? vaultManager.url(for: "recording/summary") {
                loadedSummary = try? await summaryStorage.load(
                    from: dir.appendingPathComponent(summaryFileName)
                )
            }
        }
    }
}
