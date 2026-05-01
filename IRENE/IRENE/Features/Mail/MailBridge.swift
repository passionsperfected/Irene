import Foundation

protocol MailBridgeProtocol: Sendable {
    var canReadMail: Bool { get }
    func fetchMailboxes() async throws -> [MailMailbox]
    func fetchMessages(mailboxId: String, limit: Int) async throws -> [MailMessage]
    func fetchMessage(id: String, mailboxId: String) async throws -> MailMessage?
    func sendMessage(to: [String], subject: String, body: String) async throws
    func setRead(messageId: String, mailboxId: String, read: Bool) async throws
    func deleteMessage(messageId: String, mailboxId: String) async throws
    func moveMessage(messageId: String, fromMailboxId: String, toMailboxId: String) async throws
}

#if os(macOS)
import AppKit

struct AppleScriptMailBridge: MailBridgeProtocol {
    let canReadMail = true

    // MARK: - Mailboxes

    func fetchMailboxes() async throws -> [MailMailbox] {
        print("[IRENE Mail] Fetching mailboxes...")
        let script = """
        tell application "Mail"
            set boxList to {}
            repeat with acct in accounts
                set acctName to name of acct
                repeat with mb in mailboxes of acct
                    try
                        set mbName to name of mb
                        set mbUnread to unread count of mb
                        set end of boxList to {acctName, mbName, mbUnread}
                    end try
                end repeat
            end repeat
            return boxList
        end tell
        """

        let results = try await executeScript(script)
        let boxes = results.compactMap { row -> MailMailbox? in
            guard row.count >= 3 else { return nil }
            let account = row[0]
            let name = row[1]
            let unread = Int(row[2]) ?? 0
            let id = "\(account)|\(name)"
            return MailMailbox(id: id, name: name, account: account, unreadCount: unread)
        }
        print("[IRENE Mail] Loaded \(boxes.count) mailboxes")
        return boxes
    }

    // MARK: - Fetch Messages

    func fetchMessages(mailboxId: String, limit: Int) async throws -> [MailMessage] {
        print("[IRENE Mail] Fetching \(limit) messages from: \(mailboxId)")
        let parts = parseMailboxId(mailboxId)
        let mailboxRef = mailboxReference(account: parts.account, name: parts.name)

        let script = """
        tell application "Mail"
            set msgs to {}
            set targetBox to \(mailboxRef)
            set boxMsgs to messages of targetBox
            set msgCount to count of boxMsgs
            set fetchCount to \(limit)
            if msgCount < fetchCount then set fetchCount to msgCount

            repeat with i from 1 to fetchCount
                set msg to item i of boxMsgs
                try
                    set msgSubject to subject of msg
                on error
                    set msgSubject to "(no subject)"
                end try
                set msgSender to sender of msg
                set msgDate to date received of msg
                set msgRead to read status of msg
                set msgId to message id of msg
                set end of msgs to {msgId, msgSubject, msgSender, msgDate as string, msgRead, ""}
            end repeat
            return msgs
        end tell
        """

        return try await executeScript(script).compactMap { parseMessage($0, mailboxId: mailboxId) }
    }

    // MARK: - Fetch Single Message (with content + source for HTML)

    func fetchMessage(id: String, mailboxId: String) async throws -> MailMessage? {
        print("[IRENE Mail] Fetching message: \(id.prefix(40))...")
        let escapedId = id.replacingOccurrences(of: "\"", with: "\\\"")
        let parts = parseMailboxId(mailboxId)
        let mailboxRef = mailboxReference(account: parts.account, name: parts.name)

        let script = """
        tell application "Mail"
            try
                set targetMsg to first message of \(mailboxRef) whose message id is "\(escapedId)"
                set msgBody to content of targetMsg
                set msgSource to source of targetMsg
                return {{message id of targetMsg, subject of targetMsg, sender of targetMsg, (date received of targetMsg) as string, read status of targetMsg, msgBody, msgSource}}
            on error
                return {}
            end try
        end tell
        """

        let results = try await executeScript(script)
        guard let first = results.first else { return nil }
        var msg = parseMessage(first, mailboxId: mailboxId)
        if let m = msg, first.count >= 7 {
            let source = first[6]
            msg = MailMessage(
                id: m.id,
                subject: m.subject,
                from: m.from,
                date: m.date,
                bodyPreview: m.bodyPreview,
                body: m.body,
                htmlBody: extractHTMLBody(from: source),
                isRead: m.isRead,
                mailbox: m.mailbox
            )
        }
        print("[IRENE Mail] Message loaded, body: \(msg?.body?.count ?? 0) chars, html: \(msg?.htmlBody?.count ?? 0) chars")
        return msg
    }

    // MARK: - Compose / Send

    func sendMessage(to recipients: [String], subject: String, body: String) async throws {
        let recipientList = recipients.map { "\"\(escapeAppleScript($0))\"" }.joined(separator: ", ")
        let escapedSubject = escapeAppleScript(subject)
        let escapedBody = escapeAppleScript(body)

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

    // MARK: - Mark Read / Unread

    func setRead(messageId: String, mailboxId: String, read: Bool) async throws {
        let escapedId = messageId.replacingOccurrences(of: "\"", with: "\\\"")
        let parts = parseMailboxId(mailboxId)
        let mailboxRef = mailboxReference(account: parts.account, name: parts.name)
        let readValue = read ? "true" : "false"

        let script = """
        tell application "Mail"
            try
                set targetMsg to first message of \(mailboxRef) whose message id is "\(escapedId)"
                set read status of targetMsg to \(readValue)
            end try
        end tell
        """
        _ = try await executeScript(script)
    }

    // MARK: - Delete (move to trash)

    func deleteMessage(messageId: String, mailboxId: String) async throws {
        let escapedId = messageId.replacingOccurrences(of: "\"", with: "\\\"")
        let parts = parseMailboxId(mailboxId)
        let mailboxRef = mailboxReference(account: parts.account, name: parts.name)

        let script = """
        tell application "Mail"
            try
                set targetMsg to first message of \(mailboxRef) whose message id is "\(escapedId)"
                delete targetMsg
            end try
        end tell
        """
        _ = try await executeScript(script)
    }

    // MARK: - Move to Mailbox

    func moveMessage(messageId: String, fromMailboxId: String, toMailboxId: String) async throws {
        let escapedId = messageId.replacingOccurrences(of: "\"", with: "\\\"")
        let from = parseMailboxId(fromMailboxId)
        let to = parseMailboxId(toMailboxId)
        let fromRef = mailboxReference(account: from.account, name: from.name)
        let toRef = mailboxReference(account: to.account, name: to.name)

        let script = """
        tell application "Mail"
            try
                set targetMsg to first message of \(fromRef) whose message id is "\(escapedId)"
                set mailbox of targetMsg to \(toRef)
            end try
        end tell
        """
        _ = try await executeScript(script)
    }

    // MARK: - Helpers

    private func parseMailboxId(_ id: String) -> (account: String, name: String) {
        let parts = id.split(separator: "|", maxSplits: 1).map(String.init)
        if parts.count == 2 {
            return (parts[0], parts[1])
        }
        return ("", id)
    }

    private func mailboxReference(account: String, name: String) -> String {
        if name.uppercased() == "INBOX" {
            return "inbox"
        }
        if account.isEmpty {
            return "inbox"
        }
        let escapedName = escapeAppleScript(name)
        let escapedAccount = escapeAppleScript(account)
        return "mailbox \"\(escapedName)\" of account \"\(escapedAccount)\""
    }

    private func escapeAppleScript(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func executeScript(_ source: String) async throws -> [[String]] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let script = NSAppleScript(source: source)
                let result = script?.executeAndReturnError(&error)

                if let error {
                    let msg = error[NSAppleScript.errorMessage] as? String ?? "AppleScript error"
                    let code = error[NSAppleScript.errorNumber] as? Int ?? -1
                    print("[IRENE Mail] AppleScript error (\(code)): \(msg)")
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

    private func parseMessage(_ fields: [String], mailboxId: String) -> MailMessage? {
        guard fields.count >= 5 else { return nil }
        return MailMessage(
            id: fields[0],
            subject: fields[1],
            from: fields[2],
            date: parseDate(fields[3]) ?? Date(),
            bodyPreview: fields.count > 5 ? String(fields[5].prefix(200)) : "",
            body: fields.count > 5 && !fields[5].isEmpty ? fields[5] : nil,
            isRead: fields[4] == "true",
            mailbox: mailboxId
        )
    }

    private func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.date(from: string)
    }

    /// Extract the HTML body from a raw RFC822 email source.
    /// Returns nil if no HTML part is found.
    private func extractHTMLBody(from source: String) -> String? {
        // Look for Content-Type: text/html sections
        // Simple approach: find the boundary, scan parts, return the html part body
        let lower = source.lowercased()

        // Quick check: if no html declaration anywhere, bail out
        guard lower.contains("text/html") || lower.contains("<html") else { return nil }

        // Try to find a multipart boundary
        if let boundary = extractBoundary(from: source) {
            let parts = splitByBoundary(source: source, boundary: boundary)
            for part in parts {
                let partLower = part.lowercased()
                if partLower.contains("content-type: text/html") {
                    return decodePart(part)
                }
            }
        }

        // Fallback: just look for <html...</html>
        if let htmlStart = lower.range(of: "<html") {
            // Find the actual position in original string (case-insensitive search)
            let startIndex = source.index(source.startIndex, offsetBy: source.distance(from: lower.startIndex, to: htmlStart.lowerBound))
            if let htmlEnd = lower.range(of: "</html>", range: htmlStart.upperBound..<lower.endIndex) {
                let endOffset = source.distance(from: lower.startIndex, to: htmlEnd.upperBound)
                let endIndex = source.index(source.startIndex, offsetBy: endOffset)
                return String(source[startIndex..<endIndex])
            }
        }
        return nil
    }

    private func extractBoundary(from source: String) -> String? {
        // Find boundary="..." in headers
        let pattern = #"boundary\s*=\s*"?([^";\r\n]+)"?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let nsRange = NSRange(source.startIndex..., in: source)
        guard let match = regex.firstMatch(in: source, range: nsRange),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: source) else { return nil }
        return String(source[range])
    }

    private func splitByBoundary(source: String, boundary: String) -> [String] {
        return source.components(separatedBy: "--\(boundary)")
    }

    private func decodePart(_ part: String) -> String {
        // Find the body (after the empty line that separates headers from body)
        guard let bodyStart = part.range(of: "\r\n\r\n") ?? part.range(of: "\n\n") else { return part }
        var body = String(part[bodyStart.upperBound...])

        // Detect transfer encoding from headers
        let headers = String(part[..<bodyStart.lowerBound]).lowercased()
        if headers.contains("content-transfer-encoding: quoted-printable") {
            body = decodeQuotedPrintable(body)
        } else if headers.contains("content-transfer-encoding: base64") {
            body = decodeBase64(body) ?? body
        }

        // Trim trailing boundary remnants
        if let trimRange = body.range(of: "--", options: .backwards) {
            body = String(body[..<trimRange.lowerBound])
        }

        return body
    }

    private func decodeQuotedPrintable(_ s: String) -> String {
        // Remove soft line breaks (=\n or =\r\n)
        var result = s.replacingOccurrences(of: "=\r\n", with: "")
            .replacingOccurrences(of: "=\n", with: "")

        // Decode =XX hex sequences
        let pattern = #"=([0-9A-Fa-f]{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
        let nsRange = NSRange(result.startIndex..., in: result)
        let matches = regex.matches(in: result, range: nsRange).reversed()
        for match in matches {
            guard match.numberOfRanges > 1,
                  let hexRange = Range(match.range(at: 1), in: result),
                  let fullRange = Range(match.range, in: result) else { continue }
            let hex = String(result[hexRange])
            if let byte = UInt8(hex, radix: 16) {
                let scalar = Unicode.Scalar(byte)
                result.replaceSubrange(fullRange, with: String(scalar))
            }
        }

        // Try to interpret as UTF-8 if there are escape sequences that look like multi-byte
        return result
    }

    private func decodeBase64(_ s: String) -> String? {
        let cleaned = s.replacingOccurrences(of: "\r\n", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard let data = Data(base64Encoded: cleaned) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
#endif

struct IOSMailBridge: MailBridgeProtocol {
    let canReadMail = false

    func fetchMailboxes() async throws -> [MailMailbox] { [] }

    func fetchMessages(mailboxId: String, limit: Int) async throws -> [MailMessage] {
        throw IRENEError.permissionDenied("Reading mail is not available on iOS. Use the Mail app to view messages.")
    }

    func fetchMessage(id: String, mailboxId: String) async throws -> MailMessage? {
        throw IRENEError.permissionDenied("Reading mail is not available on iOS.")
    }

    func sendMessage(to: [String], subject: String, body: String) async throws {
        throw IRENEError.permissionDenied("Use the compose view to send mail on iOS.")
    }

    func setRead(messageId: String, mailboxId: String, read: Bool) async throws {}
    func deleteMessage(messageId: String, mailboxId: String) async throws {}
    func moveMessage(messageId: String, fromMailboxId: String, toMailboxId: String) async throws {}
}
