import Foundation

struct LLMResponseChunk: Sendable {
    let text: String
    let isComplete: Bool

    init(text: String, isComplete: Bool = false) {
        self.text = text
        self.isComplete = isComplete
    }
}
