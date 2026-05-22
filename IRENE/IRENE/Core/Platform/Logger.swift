import Foundation
import os.log

private let logger = Logger(subsystem: "com.passionsperfected.irene", category: "IRENE")

enum Log {
    static func info(_ message: String) {
        logger.info("\(message, privacy: .private)")
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .private)")
    }

    static func warning(_ message: String) {
        logger.warning("\(message, privacy: .private)")
    }

    static func debug(_ message: String) {
        logger.debug("\(message, privacy: .private)")
    }
}
