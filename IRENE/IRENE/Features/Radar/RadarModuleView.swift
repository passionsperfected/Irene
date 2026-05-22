import SwiftUI
#if os(macOS)
import AppKit
#endif

struct RadarModuleView: View {
    @State private var service = RadarService()
    @Environment(\.ireneTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(theme.border.opacity(0.3))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !service.isAuthenticated {
                        authenticationView
                    } else if service.isLoading && service.displayedRadars.isEmpty {
                        loadingView
                    } else if service.displayedRadars.isEmpty {
                        emptyState
                    } else {
                        radarsList
                    }

                    if let error = service.error {
                        errorBanner(error)
                    }

                    Spacer(minLength: 40)
                }
                .padding(16)
            }
        }
        .background(theme.background)
        .task {
            if !service.isAuthenticated {
                await service.authenticateSilently()
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("Radars")
                .font(Typography.bodySemiBold(size: 14))
                .foregroundStyle(theme.primaryText)

            Text(subtitleText)
                .font(Typography.caption(size: 11))
                .foregroundStyle(theme.secondaryText)

            Spacer()

            if service.isAuthenticated {
                Button {
                    Task { await service.toggleMyRadarsFilter() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: service.showOnlyMyRadars ? "person.fill" : "person.2.fill")
                        Text(service.showOnlyMyRadars ? "My" : "All")
                    }
                    .font(Typography.button(size: 11))
                    .foregroundStyle(service.showOnlyMyRadars ? theme.accent : theme.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(service.showOnlyMyRadars ? theme.accent.opacity(0.12) : theme.secondaryBackground)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if !service.showOnlyMyRadars && !service.boards.isEmpty {
                    Menu {
                        ForEach(service.boards) { board in
                            Button {
                                Task { await service.selectBoard(board) }
                            } label: {
                                HStack {
                                    Text(board.title)
                                    if board.id == service.selectedBoard?.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.stack")
                            Text(service.selectedBoard?.title ?? "Board")
                        }
                        .font(Typography.button(size: 11))
                        .foregroundStyle(theme.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(theme.secondaryBackground)
                        .clipShape(Capsule())
                    }
                    .menuStyle(.borderlessButton)
                }

                Button {
                    Task { await service.reload() }
                } label: {
                    HStack(spacing: 4) {
                        if service.isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Reload")
                    }
                    .font(Typography.button(size: 11))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(theme.accent.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(service.isLoading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var subtitleText: String {
        if let sprint = service.activeSprint, !service.showOnlyMyRadars {
            return "\(sprint.title) • \(service.openRadars.count) open"
        } else if service.showOnlyMyRadars {
            return "\(service.myRadars.count) unread"
        } else if let board = service.selectedBoard {
            return board.title
        }
        return ""
    }

    // MARK: - States

    private var authenticationView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Radar Authentication Required")
                .font(Typography.subheading(size: 18))
                .foregroundStyle(theme.primaryText)

            Text("Connect to Radar to view your sprint radars.")
                .font(Typography.body(size: 13))
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)

            Button {
                Task { await service.authenticate() }
            } label: {
                Text("Connect to Radar")
                    .font(Typography.button(size: 12))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(theme.accent)
                    .foregroundStyle(theme.isDark ? Color.black : Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Text("Requires VPN connection and AppleConnect CLI.")
                .font(Typography.caption(size: 11))
                .foregroundStyle(theme.secondaryText.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView().scaleEffect(1.2).tint(theme.accent)
            Text("Loading radars…")
                .font(Typography.body(size: 13))
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: service.showOnlyMyRadars ? "checkmark.circle" : "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(service.showOnlyMyRadars ? theme.accent : theme.secondaryText)

            Text(service.showOnlyMyRadars ? "No radars assigned to you" : "No radars in active sprint")
                .font(Typography.subheading(size: 16))
                .foregroundStyle(theme.primaryText)

            Text(service.showOnlyMyRadars ? "You're all caught up!" : "Try a different board or check for an active sprint.")
                .font(Typography.body(size: 12))
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    // MARK: - List

    private var radarsList: some View {
        let states = ["Analyze", "Open", "Fix", "Verify", "Integrate", "Close"]
        return VStack(alignment: .leading, spacing: 16) {
            ForEach(states, id: \.self) { state in
                let radarsInState = service.displayedRadars.filter { $0.state == state }
                if !radarsInState.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            RadarStateBadge(state: state)
                            Text("(\(radarsInState.count))")
                                .font(Typography.caption(size: 10))
                                .foregroundStyle(theme.secondaryText)
                        }

                        ForEach(radarsInState) { radar in
                            RadarRow(radar: radar)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Banner

    private func errorBanner(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(error)
                .font(Typography.body(size: 12))
                .foregroundStyle(theme.primaryText)
            Spacer()
        }
        .padding(10)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Rows

struct RadarRow: View {
    let radar: Radar
    @Environment(\.ireneTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Button { openRadar() } label: {
                Text("rdar://\(radar.id)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .frame(width: 130, alignment: .leading)

            Text(radar.title)
                .font(Typography.body(size: 13))
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)

            Spacer()

            if let assignee = radar.assignee {
                Text(assignee.displayName)
                    .font(Typography.caption(size: 10))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                    .frame(width: 110, alignment: .trailing)
            }

            if let priority = radar.priority {
                PriorityBadge(priority: priority)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(theme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(theme.border.opacity(0.2), lineWidth: 1)
        )
    }

    private func openRadar() {
        guard let url = URL(string: "rdar://\(radar.id)") else { return }
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }
}

struct RadarStateBadge: View {
    let state: String
    @Environment(\.ireneTheme) private var theme

    var body: some View {
        Text(state.uppercased())
            .font(Typography.label())
            .tracking(1.2)
            .foregroundStyle(stateColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(stateColor.opacity(0.18))
            .clipShape(Capsule())
    }

    private var stateColor: Color {
        switch state.lowercased() {
        case "analyze": return .purple
        case "open": return .blue
        case "fix": return .orange
        case "verify": return .yellow
        case "integrate": return theme.accent
        case "close": return theme.secondaryText
        default: return theme.secondaryText
        }
    }
}

struct PriorityBadge: View {
    let priority: Int

    var body: some View {
        Text("P\(priority)")
            .font(Typography.label())
            .tracking(0.5)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.18))
            .clipShape(Capsule())
    }

    private var color: Color {
        switch priority {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .blue
        default: return .gray
        }
    }
}
