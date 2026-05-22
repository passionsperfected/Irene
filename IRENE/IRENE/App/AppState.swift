import Foundation
import SwiftUI

enum AppModule: String, CaseIterable, Identifiable, Sendable {
    case dashboard
    case chat
    case notes
    case stickies
    case toDo
    case reminders
    case mail
    case calendar
    case recording
    case sprints
    case github
    case radar
    case vacation

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .chat: return "Chat"
        case .notes: return "Notes"
        case .stickies: return "Stickies"
        case .toDo: return "To Do"
        case .reminders: return "Reminders"
        case .mail: return "Mail"
        case .calendar: return "Calendar"
        case .recording: return "Recording"
        case .sprints: return "Sprint Goals"
        case .github: return "GitHub"
        case .radar: return "Radar"
        case .vacation: return "Vacation"
        }
    }

    var iconName: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .chat: return "bubble.left.and.bubble.right"
        case .notes: return "doc.text"
        case .stickies: return "note.text"
        case .toDo: return "checklist"
        case .reminders: return "bell"
        case .mail: return "envelope"
        case .calendar: return "calendar"
        case .recording: return "waveform"
        case .sprints: return "flag.checkered"
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .radar: return "dot.radiowaves.left.and.right"
        case .vacation: return "sun.and.horizon"
        }
    }
}

@Observable
final class AppState {
    var selectedModule: AppModule? = .dashboard
    var showSettings: Bool = false
    var showVaultPicker: Bool = false
    var errorMessage: String?
}
