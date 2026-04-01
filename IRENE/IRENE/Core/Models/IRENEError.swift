import Foundation

enum IRENEError: LocalizedError {
    case vaultNotConfigured
    case fileNotFound(URL)
    case serializationFailed(String)
    case apiKeyMissing(String)
    case networkFailed(Error)
    case permissionDenied(String)

    var errorDescription: String? {
        switch self {
        case .vaultNotConfigured:
            return "No vault directory configured. Please select a vault location in Settings."
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .serializationFailed(let detail):
            return "Data error: \(detail)"
        case .apiKeyMissing(let provider):
            return "API key missing for \(provider). Add it in Settings."
        case .networkFailed(let error):
            return "Network error: \(error.localizedDescription)"
        case .permissionDenied(let detail):
            return "Permission denied: \(detail)"
        }
    }
}
