import SwiftUI

struct TranscriptionView: View {
    let transcription: Transcription
    @Environment(\.ireneTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("TRANSCRIPTION")
                        .font(Typography.label())
                        .tracking(2)
                        .foregroundStyle(theme.secondaryText)

                    Spacer()

                    Text("\(transcription.segments.count) segments")
                        .font(Typography.caption(size: 9))
                        .foregroundStyle(theme.secondaryText.opacity(0.5))
                }

                ForEach(Array(transcription.segments.enumerated()), id: \.offset) { _, segment in
                    HStack(alignment: .top, spacing: 10) {
                        Text(formatTimestamp(segment.timestamp))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(theme.accent.opacity(0.6))
                            .frame(width: 50, alignment: .trailing)

                        Text(segment.text)
                            .font(Typography.body(size: 13))
                            .foregroundStyle(theme.primaryText)
                            .textSelection(.enabled)
                    }
                }

                // Full text section
                Divider().overlay(theme.border.opacity(0.3))

                VStack(alignment: .leading, spacing: 6) {
                    Text("FULL TEXT")
                        .font(Typography.label())
                        .tracking(2)
                        .foregroundStyle(theme.secondaryText)

                    Text(transcription.fullText)
                        .font(Typography.body(size: 13))
                        .foregroundStyle(theme.primaryText)
                        .textSelection(.enabled)
                }
            }
            .padding(16)
        }
    }

    private func formatTimestamp(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
