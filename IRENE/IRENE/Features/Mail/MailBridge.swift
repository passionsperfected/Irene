import Foundation

protocol MailBridgeProtocol: Sendable {
    var canReadMail: Bool { get }
    func fetchInbox(limit: Int) async throws -> [MailMessage]
    func fetchMessage(id: String) async throws -> MailMessage?
    func sendMessage(to: [String], subject: String, body: String) async throws
}

#if os(macOS)
import AppKit

struct AppleScriptMailBridge: MailBridgeProtocol {
    let canReadMail = true

    func fetchInbox(limit: Int) async throws -> [MailMessage] {
        let script = """
        tell application "Mail"
            set msgs to {}
            set inboxMsgs to messages of inbox
            set msgCount to count of inboxMsgs
            set fetchCount to \(limit)
            if msgCount < fetchCount then set fetchCount to msgCount

            repeat with i from 1 to fetchCount
                set msg to item i of inboxMsgs
                set msgSubject to subject of msg
                set msgSender to sender of msg
                set msgDate to date received of msg
                set msgRead to read status of msg
                set msgId to message id of msg
                set msgPreview to ""
                try
                    set msgPreview to (content of msg)
                    if (length of msgPreview) > 200 then
                        set msgPreview to text 1 thru 200 of msgPreview
                    end if
                end try
                set end of msgs to {msgId, msgSubject, msgSender, msgDate as string, msgRead, msgPreview}
            end repeat
            return msgs
        end tell
        """

        return try await executeScript(script).compactMap { parseMessage($0) }
    }

    func fetchMessage(id: String) async throws -> MailMessage? {
        let script = """
        tell application "Mail"
            set allMsgs to messages of inbox
            repeat with msg in allMsgs
                if message id of msg is "\(id.replacingOccurrences(of: "\"", with: "\\\""))" then
                    set msgSubject to subject of msg
                    set msgSender to sender of msg
                    set msgDate to date received of msg
                    set msgRead to read status of msg
                    set msgBody to content of msg
                    return {message id of msg, msgSubject, msgSender, msgDate as string, msgRead, msgBody}
                end if
            end repeat
            return {}
        end tell
        """

        let results = try await executeScript(script)
        guard let first = results.first else { return nil }
        return parseMessage(first)
    }

    func sendMessage(to recipients: [String], subject: String, body: String) async throws {
        let recipientList = recipients.map { "\"\($0)\"" }.joined(separator: ", ")
        let escapedSubject = subject.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "Mail"
            set newMsg to make new outgoing message with properties {subject:"\(escapedSubject)", content:"\(escapedBody)", visible:true}
            tell newMsg
                repeat with addr in {\(recipientList)}
                    make new to recipient at end of to recipients with properties {address:addr}
                end repeat
            end tell
            send newMsg
        end tell
        """

        _ = try await executeScript(script)
    }

    private func executeScript(_ source: String) async throws -> [[String]] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let script = NSAppleScript(source: source)
                let result = script?.executeAndReturnError(&error)

                if let error {
                    let msg = error[NSAppleScript.errorMessage] as? String ?? "AppleScript error"
                    continuation.resume(throwing: IRENEError.permissionDenied(msg))
                    return
                }

                var parsed: [[String]] = []
                if let result, result.numberOfItems > 0 {
                    for i in 1...result.numberOfItems {
                        if let item = result.atIndex(i) {
                            var row: [String] = []
                            if item.numberOfItems > 0 {
                                for j in 1...item.numberOfItems {
                                    row.append(item.atIndex(j)?.stringValue ?? "")
                                }
                            } else {
                                row.append(item.stringValue ?? "")
                            }
                            parsed.append(row)
                        }
                    }
                }

                continuation.resume(returning: parsed)
            }
        }
    }

    private func parseMessage(_ fields: [String]) -> MailMessage? {
        guard fields.count >= 5 else { return nil }
        return MailMessage(
            id: fields[0],
            subject: fields[1],
            from: fields[2],
            date: parseDate(fields[3]) ?? Date(),
            bodyPreview: fields.count > 5 ? String(fields[5].prefix(200)) : "",
            body: fields.count > 5 ? fields[5] : nil,
            isRead: fields[4] == "true",
            mailbox: "INBOX"
        )
    }

    private func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.date(from: string)
    }
}
#endif

struct IOSMailBridge: MailBridgeProtocol {
    let canReadMail = false

    func fetchInbox(limit: Int) async throws -> [MailMessage] {
        throw IRENEError.permissionDenied("Reading mail is not available on iOS. Use the Mail app to view messages.")
    }

    func fetchMessage(id: String) async throws -> MailMessage? {
        throw IRENEError.permissionDenied("Reading mail is not available on iOS.")
    }

    func sendMessage(to: [String], subject: String, body: String) async throws {
        // On iOS, this is handled by presenting MFMailComposeViewController
        throw IRENEError.permissionDenied("Use the compose view to send mail on iOS.")
    }
}
