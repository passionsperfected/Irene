import Foundation

// MARK: - Models

struct GitHubConfig: Codable, Sendable {
    var repos: [GitHubRepoConfig]
}

struct GitHubRepoConfig: Codable, Identifiable, Hashable, Sendable {
    var id: String { "\(hostname)/\(owner)/\(repo)" }
    let hostname: String
    let owner: String
    let repo: String

    var displayName: String { "\(owner)/\(repo)" }
    var baseURL: String { "https://\(hostname)/api/v3" }
}

struct GitHubPullRequest: Codable, Identifiable, Sendable {
    let id: Int
    let number: Int
    let title: String
    let htmlURL: String
    let state: String
    let draft: Bool
    let createdAt: String
    let updatedAt: String
    let user: GitHubUser
    let head: GitHubRef
    let base: GitHubRef

    /// Enriched after fetch.
    var repoConfig: GitHubRepoConfig?
    var reviewState: PRReviewState = .none
    var checksState: PRChecksState = .none

    enum CodingKeys: String, CodingKey {
        case id, number, title, state, draft, user, head, base
        case htmlURL = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var isReadyToMerge: Bool {
        reviewState == .approved && checksState == .success && !draft
    }
}

struct GitHubUser: Codable, Sendable {
    let login: String
    let id: Int
}

struct GitHubRef: Codable, Sendable {
    let ref: String
    let sha: String
}

struct GitHubReview: Codable, Sendable {
    let id: Int
    let state: String
    let user: GitHubUser
}

struct GitHubCheckRuns: Codable, Sendable {
    let totalCount: Int
    let checkRuns: [GitHubCheckRun]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case checkRuns = "check_runs"
    }
}

struct GitHubCheckRun: Codable, Sendable {
    let id: Int
    let status: String
    let conclusion: String?
}

enum PRReviewState: String, Sendable {
    case approved = "APPROVED"
    case changesRequested = "CHANGES_REQUESTED"
    case pending = "PENDING"
    case none = "NONE"

    var displayName: String {
        switch self {
        case .approved: return "Approved"
        case .changesRequested: return "Changes Requested"
        case .pending: return "Pending Review"
        case .none: return "No Reviews"
        }
    }
}

enum PRChecksState: Sendable {
    case success
    case failure
    case pending
    case none

    var displayName: String {
        switch self {
        case .success: return "Passing"
        case .failure: return "Failing"
        case .pending: return "Running"
        case .none: return "No Checks"
        }
    }
}

// MARK: - Service

@Observable @MainActor
final class GitHubService {
    var repos: [GitHubRepoConfig] = []
    var pullRequests: [GitHubPullRequest] = []
    var isLoading = false
    var error: String?
    var lastUpdated: Date?

    private var tokens: [String: String] = [:]  // hostname → token
    private let configPath = NSString(string: "~/__ai/irene_configs/dashboard/github_config.json").expandingTildeInPath

    init() {
        loadConfig()
    }

    // MARK: - Config

    func loadConfig() {
        do {
            let url = URL(fileURLWithPath: configPath)
            let data = try Data(contentsOf: url)
            let config = try JSONDecoder().decode(GitHubConfig.self, from: data)
            repos = config.repos
            Log.info("Loaded \(repos.count) GitHub repos from config")
        } catch {
            Log.info("No GitHub config found, creating default")
            let defaultConfig = GitHubConfig(repos: [])
            repos = defaultConfig.repos
            saveConfig()
        }
    }

    func saveConfig() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(GitHubConfig(repos: repos))
            let directory = (configPath as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(
                atPath: directory,
                withIntermediateDirectories: true
            )
            try data.write(to: URL(fileURLWithPath: configPath))
            Log.info("Saved GitHub config")
        } catch {
            Log.error("Failed to save GitHub config: \(error)")
        }
    }

    func addRepo(_ repo: GitHubRepoConfig) {
        guard !repos.contains(where: { $0.id == repo.id }) else { return }
        repos.append(repo)
        saveConfig()
    }

    func removeRepo(_ repo: GitHubRepoConfig) {
        repos.removeAll { $0.id == repo.id }
        saveConfig()
    }

    // MARK: - Auth via gh CLI

    private func getToken(for hostname: String) async throws -> String {
        if let cached = tokens[hostname] { return cached }
        let token = try await fetchTokenFromGH(hostname: hostname)
        tokens[hostname] = token
        return token
    }

    private nonisolated func fetchTokenFromGH(hostname: String) async throws -> String {
        let possiblePaths = [
            "/opt/homebrew/bin/gh",
            "/usr/local/bin/gh",
            "/usr/bin/gh",
            NSString(string: "~/.local/bin/gh").expandingTildeInPath
        ]

        guard let ghPath = possiblePaths.first(where: {
            FileManager.default.fileExists(atPath: $0)
        }) else {
            throw GitHubError.authFailed("gh CLI not found. Install with: brew install gh")
        }

        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: ghPath)
        process.arguments = ["auth", "token", "--hostname", hostname]
        process.standardOutput = pipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw GitHubError.authFailed("gh auth failed: \(errorString)")
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let token = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            throw GitHubError.authFailed("No token returned from gh CLI")
        }
        return token
    }

    // MARK: - API

    private func request<T: Decodable>(_ endpoint: String, hostname: String, token: String) async throws -> T {
        let urlString = "https://\(hostname)/api/v3\(endpoint)"
        guard let url = URL(string: urlString) else {
            throw GitHubError.invalidURL(urlString)
        }

        var request = URLRequest(url: url)
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GitHubError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Refresh

    func refresh() async {
        isLoading = true
        error = nil

        var allPRs: [GitHubPullRequest] = []

        for repo in repos {
            do {
                let token = try await getToken(for: repo.hostname)
                let prs: [GitHubPullRequest] = try await request(
                    "/repos/\(repo.owner)/\(repo.repo)/pulls?state=open&per_page=100",
                    hostname: repo.hostname,
                    token: token
                )
                let tagged = prs.map { pr -> GitHubPullRequest in
                    var t = pr
                    t.repoConfig = repo
                    return t
                }
                allPRs.append(contentsOf: tagged)
                Log.info("Fetched \(prs.count) PRs from \(repo.displayName)")
            } catch {
                Log.error("Failed to fetch PRs from \(repo.displayName): \(error)")
                self.error = "Failed to fetch from \(repo.displayName): \(error.localizedDescription)"
            }
        }

        // Enrich first 25 PRs with reviews and checks.
        for i in 0..<min(allPRs.count, 25) {
            guard let repo = allPRs[i].repoConfig else { continue }
            do {
                let token = try await getToken(for: repo.hostname)

                let reviews: [GitHubReview] = try await request(
                    "/repos/\(repo.owner)/\(repo.repo)/pulls/\(allPRs[i].number)/reviews",
                    hostname: repo.hostname,
                    token: token
                )
                allPRs[i].reviewState = determineReviewState(reviews)

                let checkRuns: GitHubCheckRuns = try await request(
                    "/repos/\(repo.owner)/\(repo.repo)/commits/\(allPRs[i].head.sha)/check-runs",
                    hostname: repo.hostname,
                    token: token
                )
                allPRs[i].checksState = determineChecksState(checkRuns)
            } catch {
                Log.error("Failed to enrich PR #\(allPRs[i].number): \(error)")
            }
        }

        pullRequests = allPRs.sorted { $0.updatedAt > $1.updatedAt }
        lastUpdated = Date()
        isLoading = false
    }

    private func determineReviewState(_ reviews: [GitHubReview]) -> PRReviewState {
        var latestReviews: [Int: GitHubReview] = [:]
        for review in reviews {
            latestReviews[review.user.id] = review
        }
        let states = latestReviews.values.map { $0.state }

        if states.contains("CHANGES_REQUESTED") { return .changesRequested }
        if states.contains("APPROVED") { return .approved }
        if states.contains("PENDING") || !states.isEmpty { return .pending }
        return .none
    }

    private func determineChecksState(_ checkRuns: GitHubCheckRuns) -> PRChecksState {
        if checkRuns.totalCount == 0 { return .none }

        var hasFailure = false
        var hasPending = false

        for run in checkRuns.checkRuns {
            if run.status != "completed" {
                hasPending = true
            } else if run.conclusion != "success" && run.conclusion != "skipped" {
                hasFailure = true
            }
        }
        if hasFailure { return .failure }
        if hasPending { return .pending }
        return .success
    }

    // MARK: - Computed

    var openPRCount: Int { pullRequests.count }

    var prsByAuthor: [(login: String, prs: [GitHubPullRequest])] {
        var bucket: [String: [GitHubPullRequest]] = [:]
        for pr in pullRequests {
            bucket[pr.user.login, default: []].append(pr)
        }
        return bucket
            .map { (login: $0.key, prs: $0.value) }
            .sorted { $0.prs.count > $1.prs.count }
    }
}

// MARK: - Errors

enum GitHubError: Error, LocalizedError {
    case authFailed(String)
    case invalidURL(String)
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .authFailed(let m): return "Authentication failed: \(m)"
        case .invalidURL(let u): return "Invalid URL: \(u)"
        case .invalidResponse: return "Invalid response from server"
        case .httpError(let c): return "HTTP error: \(c)"
        }
    }
}
