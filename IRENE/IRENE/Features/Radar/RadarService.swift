import Foundation

// MARK: - Models

struct RadarBoard: Codable, Identifiable, Sendable {
    let id: Int
    let title: String
    let description: String?
}

struct RadarSprint: Codable, Identifiable, Sendable {
    let id: Int
    let title: String
    let state: String
    let startDate: String?
    let endDate: String?
    let boardId: Int

    var isActive: Bool { state.lowercased() == "active" }
}

struct RadarStory: Codable, Sendable {
    let id: Int
    let problemId: Int
    let title: String?
    let storyPoints: Int?
    let state: String?
}

struct Radar: Codable, Identifiable, Sendable {
    let id: Int
    let title: String
    let state: String
    let classification: String?
    let component: RadarComponent?
    let assignee: RadarPerson?
    let originator: RadarPerson?
    let priority: Int?
    let resolution: String?
    let substate: String?
    let createdAt: String?
    let modifiedAt: String?

    var stateColor: String {
        switch state.lowercased() {
        case "analyze": return "purple"
        case "open": return "blue"
        case "fix": return "orange"
        case "verify": return "yellow"
        case "integrate": return "green"
        case "close": return "gray"
        default: return "gray"
        }
    }
}

struct RadarComponent: Codable, Sendable {
    let id: Int?
    let name: String
    let version: String?
}

struct RadarPerson: Codable, Sendable {
    let dsid: Int?
    let firstName: String?
    let lastName: String?
    let email: String?

    var displayName: String {
        if let first = firstName, let last = lastName {
            return "\(first) \(last)"
        }
        return email ?? (dsid.map { String($0) }) ?? "Unknown"
    }
}

struct SuggestionResult: Codable, Sendable {
    let id: Int
    let type: String?
    let name: String?
    let version: String?
    let firstName: String?
    let lastName: String?
    let email: String?
    let description: String?
    let isClosed: Bool?
}

// MARK: - Service

@Observable @MainActor
final class RadarService {
    var boards: [RadarBoard] = []
    var selectedBoard: RadarBoard?
    var activeSprint: RadarSprint?
    var sprintRadars: [Radar] = []
    var myRadars: [Radar] = []
    var isLoading = false
    var error: String?
    var isAuthenticated = false
    var showOnlyMyRadars = true
    var currentUsername: String?
    var currentUserDSID: Int?

    private let baseURL = "https://radar-webservices.apple.com"
    private let clientId = "41rih2rtlg4zyax6eztzug6ftnhkun"
    private var authToken: String?
    private var tokenExpiry: Date?
    private var allSprintRadars: [Radar] = []
    private let appleConnectPath = "/usr/local/bin/appleconnect"

    var displayedRadars: [Radar] {
        showOnlyMyRadars ? myRadars : sprintRadars
    }

    init() {}

    // MARK: - Auth

    func authenticate() async {
        isLoading = true
        error = nil

        do {
            let token = try await fetchAuthToken()
            authToken = token
            tokenExpiry = Date().addingTimeInterval(9 * 60 * 60)
            isAuthenticated = true
            Log.info("Radar authenticated successfully")

            await lookupCurrentUserDSID()
            await loadMyRadars()
        } catch {
            self.error = "Authentication failed: \(error.localizedDescription)"
            isAuthenticated = false
            Log.error("Radar auth failed: \(error)")
        }

        isLoading = false
    }

    /// Authenticate without surfacing errors (for app launch).
    func authenticateSilently() async {
        do {
            let token = try await fetchAuthToken()
            authToken = token
            tokenExpiry = Date().addingTimeInterval(9 * 60 * 60)
            isAuthenticated = true
            Log.info("Radar authenticated silently")
            await lookupCurrentUserDSID()
            await loadMyRadars()
        } catch {
            Log.info("Radar silent auth skipped (not logged in)")
        }
    }

    private func fetchAuthToken() async throws -> String {
        let user = try await getCurrentUser()
        currentUsername = user
        Log.info("AppleConnect current user: \(user)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: appleConnectPath)
        process.arguments = [
            "getToken",
            "-a", user,
            "-E", "PROD",
            "-I", "900731",
            "-t", "oauth",
            "-G", "pkce",
            "-C", clientId,
            "-u", baseURL
        ]

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            Log.error("AppleConnect getToken failed: \(errorOutput)")
            throw RadarError.authenticationFailed("appleconnect getToken failed: \(errorOutput)")
        }

        for line in output.components(separatedBy: "\n") {
            if line.hasPrefix("oauth-access-token:") {
                let token = line
                    .replacingOccurrences(of: "oauth-access-token:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if !token.isEmpty { return token }
            }
        }
        throw RadarError.authenticationFailed("Could not parse token from appleconnect output")
    }

    private func getCurrentUser() async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: appleConnectPath)
        process.arguments = ["currentUser"]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let lines = output.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("Support for") }

        guard let username = lines.last, !username.isEmpty else {
            throw RadarError.authenticationFailed("Could not get current AppleConnect user. Run 'appleconnect login'.")
        }
        return username
    }

    private func ensureAuthenticated() async throws {
        if authToken == nil || (tokenExpiry != nil && Date() > tokenExpiry!) {
            await authenticate()
        }
        guard isAuthenticated, authToken != nil else {
            throw RadarError.notAuthenticated
        }
    }

    // MARK: - Requests

    private func request<T: Decodable>(_ path: String, method: String = "GET", body: Data? = nil) async throws -> T {
        try await ensureAuthenticated()

        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw RadarError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authToken, forHTTPHeaderField: "X-Apple-OIDC-Access-Token")
        request.setValue("IRENE/1.0", forHTTPHeaderField: "User-Agent")
        if let body { request.httpBody = body }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RadarError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            authToken = nil
            isAuthenticated = false
            throw RadarError.notAuthenticated
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw RadarError.httpError(httpResponse.statusCode, errorBody)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func requestWithBody<T: Decodable>(_ path: String, method: String, bodyString: String) async throws -> T {
        try await ensureAuthenticated()

        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw RadarError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authToken, forHTTPHeaderField: "X-Apple-OIDC-Access-Token")
        request.setValue("IRENE/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RadarError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw RadarError.httpError(httpResponse.statusCode, errorBody)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - User lookup

    private func lookupCurrentUserDSID() async {
        guard let username = currentUsername else { return }
        let nameParts = username.split(separator: "_").map { $0.capitalized }
        let displayName = nameParts.joined(separator: " ")

        do {
            let bodyString = """
            {"search":"\(displayName)","types":["person"],"rows":10}
            """
            let results: [SuggestionResult] = try await requestWithBody(
                "/suggestion",
                method: "POST",
                bodyString: bodyString
            )

            if let match = results.first(where: {
                let fullName = "\($0.firstName ?? "") \($0.lastName ?? "")".lowercased()
                return fullName == displayName.lowercased()
            }) ?? results.first {
                currentUserDSID = match.id
                Log.info("Found DSID \(match.id) for \(displayName)")
            }
        } catch {
            Log.error("Failed to look up user DSID: \(error)")
        }
    }

    // MARK: - My radars

    func loadMyRadars() async {
        guard let dsid = currentUserDSID else {
            myRadars = []
            return
        }

        isLoading = true
        error = nil

        do {
            let bodyString = """
            {"assigneeId":\(dsid),"state":{"neq":"Closed"},"isReadByAssignee":false}
            """
            let radars: [Radar] = try await requestWithBody(
                "/problems/find",
                method: "POST",
                bodyString: bodyString
            )
            myRadars = radars.sorted { ($0.priority ?? 999) < ($1.priority ?? 999) }
            Log.info("Loaded \(myRadars.count) unread radars assigned to me")
        } catch {
            self.error = "Failed to load my radars: \(error.localizedDescription)"
            Log.error("Failed to load my radars: \(error)")
            myRadars = []
        }

        isLoading = false
    }

    // MARK: - Boards / sprints

    func loadBoards() async {
        isLoading = true
        error = nil

        do {
            let response: [RadarBoard] = try await request("/boards")
            boards = response
            Log.info("Loaded \(boards.count) boards")
            if selectedBoard == nil, let first = boards.first {
                await selectBoard(first)
            }
        } catch {
            self.error = "Failed to load boards: \(error.localizedDescription)"
            Log.error("Load boards failed: \(error)")
        }

        isLoading = false
    }

    func selectBoard(_ board: RadarBoard) async {
        selectedBoard = board
        await loadActiveSprint()
    }

    func loadActiveSprint() async {
        guard let board = selectedBoard else { return }
        isLoading = true
        error = nil

        do {
            let response: [RadarSprint] = try await request("/boards/\(board.id)/sprints")
            activeSprint = response.first { $0.isActive }

            if let sprint = activeSprint {
                Log.info("Found active sprint: \(sprint.title)")
                await loadSprintRadars(sprint)
            } else {
                Log.info("No active sprint for board \(board.title)")
                sprintRadars = []
            }
        } catch {
            self.error = "Failed to load sprints: \(error.localizedDescription)"
            Log.error("Load sprints failed: \(error)")
        }

        isLoading = false
    }

    func loadSprintRadars(_ sprint: RadarSprint) async {
        guard let board = selectedBoard else { return }

        do {
            let stories: [RadarStory] = try await request("/boards/\(board.id)/sprints/\(sprint.id)/items")
            let problemIds = stories.map { $0.problemId }

            if problemIds.isEmpty {
                allSprintRadars = []
                applyRadarFilter()
                return
            }

            var radars: [Radar] = []
            for chunk in problemIds.chunked(into: 75) {
                let ids = chunk.map { String($0) }.joined(separator: ",")
                let fetched: [Radar] = try await request("/problems/\(ids)")
                radars.append(contentsOf: fetched)
            }

            allSprintRadars = radars.sorted { ($0.priority ?? 999) < ($1.priority ?? 999) }
            applyRadarFilter()
            Log.info("Loaded \(allSprintRadars.count) radars for \(sprint.title), showing \(sprintRadars.count)")
        } catch {
            self.error = "Failed to load radars: \(error.localizedDescription)"
            Log.error("Load radars failed: \(error)")
        }
    }

    func applyRadarFilter() {
        if showOnlyMyRadars, let username = currentUsername {
            let nameParts = username.split(separator: "_").map { $0.capitalized }
            let displayName = nameParts.joined(separator: " ")
            sprintRadars = allSprintRadars.filter { radar in
                guard let assignee = radar.assignee else { return false }
                return assignee.displayName.lowercased() == displayName.lowercased()
            }
        } else {
            sprintRadars = allSprintRadars
        }
    }

    func toggleMyRadarsFilter() async {
        showOnlyMyRadars.toggle()
        if showOnlyMyRadars {
            await loadMyRadars()
        } else if boards.isEmpty {
            await loadBoards()
        }
    }

    func reload() async {
        if showOnlyMyRadars {
            await loadMyRadars()
        } else if let board = selectedBoard {
            await selectBoard(board)
        }
    }

    // MARK: - Computed

    var openRadars: [Radar] {
        sprintRadars.filter { !["Close", "Verify"].contains($0.state) }
    }
}

// MARK: - Errors

enum RadarError: LocalizedError {
    case notAuthenticated
    case authenticationFailed(String)
    case invalidURL
    case invalidResponse
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not authenticated with Radar"
        case .authenticationFailed(let m): return "Authentication failed: \(m)"
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .httpError(let code, let message): return "HTTP \(code): \(message)"
        }
    }
}

// MARK: - Array chunking helper

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
