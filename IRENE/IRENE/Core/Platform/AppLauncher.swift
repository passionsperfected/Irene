import Foundation

#if os(macOS)
import AppKit
#endif

enum ExternalApp: String, Sendable {
    case mail = "com.apple.mail"
    case calendar = "com.apple.iCal"

    var displayName: String {
        switch self {
        case .mail: return "Mail"
        case .calendar: return "Calendar"
        }
    }

    var bundleIdentifier: String { rawValue }

    /// Well-known install path, used as a fallback when Launch Services
    /// can't resolve the bundle ID inside the sandbox.
    var fallbackPath: String {
        switch self {
        case .mail: return "/System/Applications/Mail.app"
        case .calendar: return "/System/Applications/Calendar.app"
        }
    }
}

#if os(macOS)
@MainActor
enum AppLauncher {
    static func isRunning(_ app: ExternalApp) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier).isEmpty
    }

    /// Launch `app` if it isn't already running. Returns once the app is detected
    /// running, or after a short timeout if it never appears.
    @discardableResult
    static func launch(_ app: ExternalApp) async throws -> Bool {
        if isRunning(app) { return true }

        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier)
            ?? URL(fileURLWithPath: app.fallbackPath)

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        config.addsToRecentItems = false

        do {
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
        } catch {
            print("[IRENE AppLauncher] openApplication failed for \(app.displayName) at \(url.path): \(error)")
            throw IRENEError.permissionDenied("Couldn't open \(app.displayName): \(error.localizedDescription)")
        }

        for _ in 0..<25 {
            if isRunning(app) { return true }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return isRunning(app)
    }
}
#endif
