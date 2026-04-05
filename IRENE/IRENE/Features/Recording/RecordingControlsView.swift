import SwiftUI

struct RecordingControlsView: View {
    @Bindable var viewModel: RecordingViewModel
    @Environment(\.ireneTheme) private var theme
    @State private var title: String = "Meeting Recording"

    var body: some View {
        HStack(spacing: 14) {
            // Record/Stop button
            Button {
                Task {
                    if viewModel.captureService.isRecording {
                        await viewModel.stopRecording()
                    } else {
                        await viewModel.startRecording(source: .micOnly, title: title)
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(viewModel.captureService.isRecording ? .red : theme.accent)
                        .frame(width: 36, height: 36)

                    if viewModel.captureService.isRecording {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                    } else {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .buttonStyle(.plain)

            if viewModel.captureService.isRecording {
                // Timer
                Text(formatTime(viewModel.captureService.elapsedTime))
                    .font(.system(size: 16, weight: .light, design: .monospaced))
                    .foregroundStyle(theme.primaryText)

                // Audio level meter
                AudioLevelView(level: viewModel.captureService.audioLevel)
                    .frame(width: 100, height: 16)
            } else {
                // Title field
                TextField("Recording title", text: $title)
                    .font(Typography.body(size: 13))
                    .textFieldStyle(.plain)
                    .foregroundStyle(theme.primaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(theme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Spacer()

            if viewModel.captureService.isRecording {
                Text("Recording...")
                    .font(Typography.caption(size: 10))
                    .foregroundStyle(.red.opacity(0.8))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    viewModel.captureService.isRecording ? Color.red.opacity(0.3) : theme.border.opacity(0.2),
                    lineWidth: 1
                )
        )
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct AudioLevelView: View {
    let level: Float
    @Environment(\.ireneTheme) private var theme

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(0..<16, id: \.self) { i in
                    let threshold = Float(i) / 16.0
                    RoundedRectangle(cornerRadius: 1)
                        .fill(level > threshold ? barColor(i) : theme.secondaryText.opacity(0.15))
                        .frame(width: max((geo.size.width - 15) / 16, 2))
                }
            }
        }
    }

    private func barColor(_ index: Int) -> Color {
        if index > 12 { return .red }
        if index > 9 { return .orange }
        return .green
    }
}
