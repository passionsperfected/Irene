import SwiftUI
#if os(macOS)
import AppKit
#endif

struct GitHubModuleView: View {
    @State private var service = GitHubService()
    @State private var showRepoEditor = false
    @State private var newHostname = ""
    @State private var newOwner = ""
    @State private var newRepo = ""

    @Environment(\.ireneTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(theme.border.opacity(0.3))

            if service.isLoading && service.pullRequests.isEmpty {
                loadingView
            } else if service.repos.isEmpty {
                EmptyStateView(
                    icon: "chevron.left.forwardslash.chevron.right",
                    title: "No Repositories",
                    message: "Add a repo to start tracking PRs.",
                    action: { showRepoEditor = true },
                    actionLabel: "Manage Repos"
                )
            } else if service.pullRequests.isEmpty && service.lastUpdated == nil {
                EmptyStateView(
                    icon: "arrow.clockwise.circle",
                    title: "Ready to Refresh",
                    message: "Tap Refresh to fetch open PRs from \(service.repos.count) repo\(service.repos.count == 1 ? "" : "s").",
                    action: { Task { await service.refresh() } },
                    actionLabel: "Refresh"
                )
            } else if service.pullRequests.isEmpty {
                emptyState
            } else {
                content
            }

            if let error = service.error {
                errorBanner(error)
            }
        }
        .background(theme.background)
        .task {
            if !service.repos.isEmpty && service.lastUpdated == nil {
                await service.refresh()
            }
        }
        .sheet(isPresented: $showRepoEditor) {
            repoEditorSheet
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("Pull Requests")
                .font(Typography.bodySemiBold(size: 14))
                .foregroundStyle(theme.primaryText)

            if service.openPRCount > 0 {
                Text("\(service.openPRCount) open")
                    .font(Typography.caption(size: 10))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.accent.opacity(0.15))
                    .clipShape(Capsule())
            }

            Spacer()

            if let last = service.lastUpdated {
                Text("Updated \(last, style: .relative) ago")
                    .font(Typography.caption(size: 10))
                    .foregroundStyle(theme.secondaryText.opacity(0.7))
            }

            Button { showRepoEditor = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                    Text("Repos")
                }
                .font(Typography.button(size: 11))
                .foregroundStyle(theme.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(theme.secondaryBackground)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                Task { await service.refresh() }
            } label: {
                HStack(spacing: 4) {
                    if service.isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Refresh")
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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(service.pullRequests) { pr in
                    PRRow(pr: pr)
                }
            }
            .padding(12)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView().scaleEffect(1.2).tint(theme.accent)
            Text("Loading PRs…")
                .font(Typography.body(size: 12))
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 36))
                .foregroundStyle(.green)
            Text("All caught up!")
                .font(Typography.subheading(size: 18))
                .foregroundStyle(theme.primaryText)
            Text("No open PRs across \(service.repos.count) repo\(service.repos.count == 1 ? "" : "s").")
                .font(Typography.body(size: 12))
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorBanner(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(error)
                .font(Typography.caption(size: 11))
                .foregroundStyle(theme.primaryText)
                .lineLimit(2)
            Spacer()
            Button {
                service.error = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.secondaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - Repo editor

    private var repoEditorSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Repositories")
                .font(Typography.subheading(size: 18))
                .foregroundStyle(theme.primaryText)

            if service.repos.isEmpty {
                Text("No repositories configured.")
                    .font(Typography.body(size: 12))
                    .foregroundStyle(theme.secondaryText)
            } else {
                VStack(spacing: 6) {
                    ForEach(service.repos) { repo in
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(repo.displayName)
                                    .font(Typography.bodyMedium(size: 13))
                                    .foregroundStyle(theme.primaryText)
                                Text(repo.hostname)
                                    .font(Typography.caption(size: 10))
                                    .foregroundStyle(theme.secondaryText)
                            }
                            Spacer()
                            Button {
                                service.removeRepo(repo)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.secondaryText.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(theme.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            Divider().overlay(theme.border.opacity(0.2))

            VStack(alignment: .leading, spacing: 8) {
                Text("ADD REPOSITORY")
                    .font(Typography.label())
                    .tracking(1.2)
                    .foregroundStyle(theme.secondaryText)

                TextField("hostname (e.g. github.com or github.example.com)", text: $newHostname)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(theme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                HStack(spacing: 8) {
                    TextField("owner", text: $newOwner)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(theme.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    TextField("repo", text: $newRepo)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(theme.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Button("Add") { addRepo() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(theme.accent.opacity(0.15))
                    .clipShape(Capsule())
                    .disabled(newHostname.isEmpty || newOwner.isEmpty || newRepo.isEmpty)
            }

            HStack {
                Spacer()
                Button("Done") { showRepoEditor = false }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(theme.accent.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(20)
        .frame(width: 460)
        .background(theme.background)
    }

    private func addRepo() {
        let host = newHostname.trimmingCharacters(in: .whitespaces)
        let owner = newOwner.trimmingCharacters(in: .whitespaces)
        let repo = newRepo.trimmingCharacters(in: .whitespaces)
        guard !host.isEmpty, !owner.isEmpty, !repo.isEmpty else { return }
        service.addRepo(GitHubRepoConfig(hostname: host, owner: owner, repo: repo))
        newHostname = ""
        newOwner = ""
        newRepo = ""
    }
}

// MARK: - PR row

struct PRRow: View {
    let pr: GitHubPullRequest
    @Environment(\.ireneTheme) private var theme

    var body: some View {
        Button { openPR() } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(pr.title)
                    .font(Typography.bodyMedium(size: 13))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    Text("#\(pr.number)")
                        .font(Typography.caption(size: 10))
                        .foregroundStyle(theme.accent)
                    if let repo = pr.repoConfig {
                        Text(repo.displayName)
                            .font(Typography.caption(size: 10))
                            .foregroundStyle(theme.secondaryText)
                    }
                    Spacer()
                    if pr.draft {
                        Text("DRAFT")
                            .font(Typography.label())
                            .tracking(1)
                            .foregroundStyle(theme.secondaryText)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(theme.border.opacity(0.3))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "person")
                            .font(.system(size: 9))
                        Text(pr.user.login).font(Typography.caption(size: 10))
                    }
                    .foregroundStyle(theme.secondaryText)

                    reviewBadge
                    checksBadge

                    Spacer()
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
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var reviewBadge: some View {
        let info = reviewBadgeInfo
        HStack(spacing: 3) {
            Image(systemName: info.icon).font(.system(size: 9))
            Text(info.text).font(Typography.caption(size: 10))
        }
        .foregroundStyle(info.color)
    }

    private var reviewBadgeInfo: (icon: String, color: Color, text: String) {
        switch pr.reviewState {
        case .approved: return ("checkmark.circle.fill", .green, "Approved")
        case .changesRequested: return ("xmark.circle.fill", .red, "Changes")
        case .pending: return ("clock", .orange, "Pending")
        case .none: return ("circle", theme.secondaryText, "No reviews")
        }
    }

    @ViewBuilder
    private var checksBadge: some View {
        let info = checksBadgeInfo
        Image(systemName: info.icon)
            .font(.system(size: 11))
            .foregroundStyle(info.color)
    }

    private var checksBadgeInfo: (icon: String, color: Color) {
        switch pr.checksState {
        case .success: return ("checkmark.circle.fill", .green)
        case .failure: return ("xmark.circle.fill", .red)
        case .pending: return ("clock.fill", .orange)
        case .none: return ("circle.dashed", theme.secondaryText)
        }
    }

    private func openPR() {
        guard let url = URL(string: pr.htmlURL) else { return }
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }
}
