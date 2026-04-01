import SwiftUI

struct RecordingControlsView: View {
    @Bindable var viewModel: RecordingViewModel
    @Environment(\.ireneTheme) private var theme
    @State private var title: String = "Meeting Recording"
    @State private var selectedSource: AudioSource = .micOnly

    var body: some View {
        VStack(spacing: 16) {
            // Title
            TextField("Recording title", text: $title)
                .font(Typography.body(size: 14))
                .textFieldStyle(.plain)
                .foregroundStyle(theme.primaryText)
                .padding(10)
                .background(theme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Audio source picker
            if viewModel.captureService.canCaptureSystemAudio {
                Picker("Source", selection: $selectedSource) {
                    ForEach(AudioSource.allCases, id: \.self) { source in
                        Text(source.rawValue).tag(source)
                    }
                }
                .pickerStyle(.segmented)
                .font(Typography.body(size: 12))
            }

            // Record button + timer
            HStack(spacing: 20) {
                if viewModel.captureService.isRecording {
                    // Timer
                    Text(formatTime(viewModel.captureService.elapsedTime))
                        .font(.system(size: 24, weight: .light, design: .monospaced))
                        .foregroundStyle(theme.primaryText)

                    // Audio level meter
                    AudioLevelView(level: viewModel.captureService.audioLevel)
                        .frame(height: 24)
                }
            }

            // Record/Stop button
            Button {
                Task {
                    if viewModel.captureService.isRecording {
                        await viewModel.stopRecording()
                    } else {
                        await viewModel.startRecording(source: selectedSource, title: title)
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(viewModel.captureService.isRecording ? .red : theme.accent)
                        .frame(width: 56, height: 56)

                    if viewModel.captureService.isRecording {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                    } else {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                    }
                }
            }
            .buttonStyle(.plain)

            Text(viewModel.captureService.isRecording ? "Tap to stop" : "Tap to record")
                .font(Typography.caption(size: 10))
                .foregroundStyle(theme.secondaryText.opacity(0.5))
        }
        .padding(20)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        let tenths = Int((interval.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
}

struct AudioLevelView: View {
    let level: Float
    @Environment(\.ireneTheme) private var theme

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(0..<20, id: \.self) { i in
                    let threshold = Float(i) / 20.0
                    RoundedRectangle(cornerRadius: 1)
                        .fill(level > threshold * 0.3 ? barColor(i) : theme.secondaryText.opacity(0.15))
                        .frame(width: max((geo.size.width - 38) / 20, 2))
                }
            }
        }
    }

    private func barColor(_ index: Int) -> Color {
        if index > 16 { return .red }
        if index > 12 { return .orange }
        return .green
    }
}
