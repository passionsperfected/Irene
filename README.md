# IRENE

**Intelligent Reasoning Engine & Natural Engagement**

A Mac-native productivity and note-taking app powered by LLMs. IRENE combines notes, conversations, tasks, reminders, recordings, mail, and calendar into a single app with a file-based vault and deep AI integration.

Built with SwiftUI targeting macOS 14+, iOS 17+.

---

## Modules

### Dashboard
- Daily greeting with time-aware message (morning/afternoon/evening)
- Summary cards showing counts for inbox tasks, reminders, recent notes, and stickies
- Cards are tappable — navigate directly to the relevant module
- Recent activity feed showing today's tasks, overdue items, and upcoming reminders
- Embedded IRENE chat with full context — ask "What's on my plate today?" and get a response synthesized from all your data

### Chat
- Full conversation interface with streaming LLM responses (word-by-word)
- Conversation list with search, sorted by last modified
- Markdown rendering in assistant messages
- Stop generating, retry, copy, and delete message actions
- Model picker — switch between Claude Sonnet 4, Opus 4.1, Opus 4.5, Opus 4.6
- Personality picker — change IRENE's communication style per conversation
- Conversations persist as JSON files in the vault

### Notes (Sublime-style File Browser)
- Hierarchical file tree with folders and files
- Supports `.txt` (default), `.md`, and `.json` file types
- Create files instantly with Cmd+N (creates `untitled.txt`)
- Create files with a specific type via the menu
- Create and nest folders
- Rename files by clicking the filename in the editor toolbar — change name and extension
- Drag and drop files into folders
- Right-click context menus: New File, New Folder, Rename, Delete
- Monospaced editor with auto-save (1.5s debounce) and save-on-switch
- Smart quotes and auto-correction disabled for clean code/text editing
- **Markdown files**: Preview/Edit toggle with full rendered markdown (headings, lists, code blocks, blockquotes, bold, italic, strikethrough, links, inline code)
- **JSON files**: Format button that pretty-prints with indentation and sorted keys, auto-fixes smart quotes before parsing
- **All files**: AI assistant sidebar — ask IRENE about the file content
- Bottom status bar: file type badge, line count, word count, encoding
- Error bar for format/save errors with dismiss

### Stickies
- Masonry grid of sticky note cards
- 5 themed color options (Accent, Secondary, Warm, Neutral, Muted)
- Quick capture view for fast note entry
- Edit sticky content, color, and tags
- Search across all stickies
- System-wide hotkey: `Control + Option + Command + 0` (macOS)

### To Do
- Sectioned task list: Inbox, Overdue, Today, Upcoming, Completed
- Priority levels: Low, Medium, High, Urgent (with color-coded badges)
- Due dates with overdue indicators
- Inbox workflow — quick-captured items land in inbox, then get triaged
- Toggle completion with checkmark
- Full detail editor: title, description, priority, due date, tags, inbox toggle
- Quick capture view — single text field, adds to inbox
- Show/hide completed items
- System-wide hotkey: `Control + Option + Command + =` (macOS)

### Reminders
- Sectioned list: Overdue, Today, Upcoming, Completed
- Date and time picker with quick-set buttons (1 hour, 3 hours, Tomorrow)
- Recurring reminders: daily, weekly, monthly, yearly with configurable intervals
- Local notifications via `UNUserNotificationCenter`
- Notifications reschedule on app launch
- Quick capture view with date/time selection
- System-wide hotkey: `Control + Option + Command + -` (macOS)

### Calendar
- Apple Calendar integration via EventKit (read and write)
- Month view with date picker
- Day detail showing events with times, locations, and calendar names
- Create new events with title, start/end times, all-day toggle, location, notes
- Navigation: previous/next month, today button
- Permission request flow for calendar access

### Mail
- **macOS**: Read inbox via AppleScript bridge to Mail.app — view sender, subject, date, body preview
- **macOS**: Read full message body by selecting a message
- **All platforms**: Compose and send email
- Split view: message list + message detail
- Unread indicator dots
- **iOS**: Note that reading mail requires macOS; compose-only on iOS

### Recording
- Microphone audio capture via `AVAudioEngine`
- System audio capture via `ScreenCaptureKit` (macOS only — captures WebEx, Zoom, etc.)
- Audio source picker: System + Mic, Mic Only, System Only
- Live audio level meter during recording
- Duration timer
- On-device transcription via `SFSpeechRecognizer` with timestamped segments
- LLM-powered meeting summarization: summary, key topics, action items
- "Create To Do from action item" — push action items directly to the To Do inbox
- Recording list with status badges (Recording, Transcribing, Summarizing, Complete, Failed)
- Transcription viewer with timestamps
- Summary viewer with structured sections

---

## Settings
- **Vault**: Choose vault location (iCloud recommended for sync), view current path
- **Theme**: 15 selectable color themes with live preview swatches
- **LLM Provider**: Switch between Anthropic, OpenAI (stub), Grok (stub)
- **API Keys**: Secure fields for Anthropic, OpenAI, and Grok keys
- **Personality**: 6 presets that change how IRENE communicates:
  - Professional Assistant — formal, concise, task-focused
  - Creative Companion — warm, curious, idea-generating
  - Research Analyst — thorough, analytical, multiple perspectives
  - Casual Friend — conversational, encouraging, relaxed
  - Socratic Tutor — guides through questions, encourages discovery
  - Executive Secretary — sharp, polished, playfully charming
- Save button with confirmation indicator
- Close button (X)

---

## Themes

15 built-in color themes with 39 design tokens each:

| Theme | Style |
|-------|-------|
| Arctic Frost | Cyan/indigo on dark navy |
| Citrus Slate | Yellow-green/orange on dark grey |
| Cloud Sky | Blue on light blue (light theme) |
| Crimson Gold | Red/gold on dark crimson |
| Cyberpunk | Lime/purple on near-black |
| Deep Ocean | Teal/purple on deep navy |
| Lavender Pearl | Lavender on cream (light theme) |
| Monokai | Green/magenta on warm brown |
| Moonrise | Silver-blue/amber on dark blue |
| Neon Noir | Hot pink/electric blue on black |
| Obsidian Copper | Copper/teal on dark grey |
| Parchment | Brown/olive on cream (light theme) |
| Sage Linen | Green/rose on warm cream (light theme) |
| Sakura | Pink/orange on warm dark |
| Solar Amber | Amber/terracotta on dark warm |

---

## Architecture

- **SwiftUI** multiplatform app (macOS + iOS targets)
- **Swift 6** with strict concurrency
- **MVVM** with `@Observable` ViewModels
- **File-based vault** — all data stored as plain text/JSON (like Obsidian). No database.
- **LLM Provider protocol** — extensible to any LLM API. Currently implements Anthropic Claude with raw `URLSession` streaming (no SDK dependency).
- **Theme engine** — 39 design tokens delivered via `@Environment(\.ireneTheme)`, custom SwiftUI modifiers
- **Typography system** — Cinzel Decorative (headings), Cormorant Garamond (subheadings), Rajdhani (body/UI)
- **Global hotkeys** (macOS) — `NSEvent` monitoring with floating `NSPanel` for quick capture from any app
- **EventKit** for Calendar, **AppleScript** for Mail, **ScreenCaptureKit** for system audio, **Speech** framework for transcription

### Vault Structure
```
vault/
  notes/           — files and folders (.txt, .md, .json)
  sticky_notes/    — sticky notes as JSON
  to_do/           — tasks as JSON
  reminders/       — reminders as JSON
  chats/           — conversations as JSON
  recording/
    audio/         — recorded audio files
    transcription/ — transcription JSON
    summary/       — AI summary JSON
  settings/
    config.json    — API keys, theme, personality, provider
    system_prompts/— custom personality prompts
    metadata/      — item metadata sidecars
```

### Dependencies
- `apple/swift-markdown` — Markdown AST parsing for rendered preview
- No other third-party dependencies. All networking, audio, transcription, and platform integration uses Apple frameworks.

---

## Building

Requires Xcode 16+ and macOS 14+.

```bash
cd IRENE
xcodegen generate
xcodebuild -project IRENE.xcodeproj -scheme IRENE_macOS -destination 'platform=macOS' build
```

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the `.xcodeproj` from `project.yml`.

---

## Project Stats

- **90 Swift source files**
- **15 theme JSON files**
- **9 modules** (Dashboard, Chat, Notes, Stickies, To Do, Reminders, Mail, Calendar, Recording)
- **4 LLM models** supported (Claude Sonnet 4, Opus 4.1, 4.5, 4.6)
- **6 personality presets**
- **0 third-party SDK dependencies** for networking or LLM integration
