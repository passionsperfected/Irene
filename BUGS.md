# IRENE — Known Bugs & Open Issues

Tracks known defects and small enhancement items. For larger feature work, see roadmap.

---

## Crash Risks (force unwraps)

### 1. AudioCaptureService — force-unwrapped audio formats and channel data
- **File:** `IRENE/IRENE/Features/Recording/AudioCaptureService.swift:272, 311, 323, 326`
- **Issue:** `AVAudioFormat(standardFormatWithSampleRate:channels:)!` and `buffer.floatChannelData![0]` will crash if the audio subsystem rejects the format or returns no channel data. Line 326 (`memcpy`) also writes without bounds checking beyond `samples.count`.
- **Fix:** Replace `!` with `guard let` + throw `IRENEError.serializationFailed`. Verify `buffer.frameCapacity >= samples.count` before `memcpy`.

### 2. MultiCursorController — empty-selection crashes
- **File:** `IRENE/IRENE/Features/Notes/Editor/MultiCursorController.swift:51, 60`
- **Issue:** `state.selections.last!` and `.first!` crash if the selections array is empty (possible during edit/undo cycles).
- **Fix:** Guard with `guard let last = state.selections.last else { return }`.

### 3. CalendarViewModel — date arithmetic force unwraps
- **File:** `IRENE/IRENE/Features/Calendar/CalendarViewModel.swift:21, 30, 51, 52`
- **Issue:** `calendar.date(byAdding:...)!` chains. Calendar math returning nil is rare but possible (DST, locale edge cases).
- **Fix:** Guard, fall back to current date or skip the operation.

### 4. NSTextViewBridge — text container & glyph rect
- **File:** `IRENE/IRENE/Features/Notes/Editor/NSTextViewBridge.swift:201`
- **Issue:** Force-unwrapped `textContainer`. Crashes if the text view is being torn down while a layout pass runs.
- **Fix:** Guard, return early.

### 5. LineNumberGutterView — fatalError + force unwrap
- **File:** `IRENE/IRENE/Features/Notes/Editor/LineNumberGutterView.swift:11, 28`
- **Issue:** `fatalError("init(coder:)")` and force-unwrapped `enclosingScrollView`.
- **Fix:** Replace `fatalError` with `super.init(coder:)`; guard the scroll view.

### 6. AnthropicProvider — baseURL force unwrap
- **File:** `IRENE/IRENE/Core/LLM/Providers/AnthropicProvider.swift:101, 131`
- **Issue:** `URL(string: Self.baseURL)!`. Static string so safe today, but fragile.
- **Fix:** Lift to a `static let url = URL(string: ...)!` initialized once, or use `URLComponents`.

---

## Threading & Concurrency

### 7. AudioCaptureService — `nonisolated(unsafe)` in converter callback
- **File:** `IRENE/IRENE/Features/Recording/AudioCaptureService.swift:289-300`
- **Issue:** `nonisolated(unsafe) var gotData` mutated from inside `AVAudioConverter` callback. Defeats Swift 6 strict concurrency.
- **Fix:** Wrap state in a small `final class` holder, or convert the function to use `withCheckedContinuation` with a serial actor.

### 8. TranscriptionService — late callback after cancellation
- **File:** `IRENE/IRENE/Features/Recording/TranscriptionService.swift:62-75`
- **Issue:** `SFSpeechRecognizer` recognition callback delivers a result even after the task is cancelled.
- **Fix:** Capture `Task` handle, check `Task.isCancelled` (or a local `isCancelled` flag) before publishing the segment.

### 9. AudioCaptureService — race in `finishWriting` + stop
- **File:** `IRENE/IRENE/Features/Recording/AudioCaptureService.swift:80-92`
- **Issue:** Async finishWriting → MainActor merge. If `stopRecording()` fires twice quickly, temp files could be merged twice.
- **Fix:** Add an `isFinalizing` guard, or store a `Task` handle and `await` it on subsequent stops.

### 10. `@unchecked Sendable` overrides
- **Files:** `Core/Vault/VaultManager.swift:5`, `Core/Theme/ThemeManager.swift:5`, `Core/Platform/GlobalHotkey.swift`, `Features/Recording/AudioCaptureService.swift:9`
- **Issue:** Strict concurrency is enabled project-wide but these classes opt out.
- **Fix:** Convert to `@MainActor` (Theme, Vault) or actors; remove the `@unchecked Sendable` once mutation is properly isolated.

---

## Silent Error Swallowing

### 11. Pervasive `try?` without logging
- **Files:**
  - `Core/Vault/JSONStorage.swift:47` (already has a "log in the future" comment)
  - `Core/Vault/VaultManager.swift:94, 104, 107`
  - `Features/Notes/FileTreeViewModel.swift:31-32, 55-58`
  - `App/AppDelegate.swift:134, 137, 144`
  - Multiple ViewModels (Stickies, Chat, Recording)
- **Issue:** Failures are invisible; debugging "why didn't my note load" becomes guesswork.
- **Fix:** Introduce a thin `Logger` wrapper (`os.Logger`) and convert `try?` to `do/catch` that logs at `.error` level. Keep behavior (no user-visible error) where appropriate.

---

## Mail-Specific

### 12. Fragile MIME / HTML body parsing
- **File:** `IRENE/IRENE/Features/Mail/MailBridge.swift:305-335`
- **Issue:** Regex/string-split MIME parsing. Breaks on nested multipart, encoded boundaries, quoted-printable encoding, non-UTF8 charsets.
- **Fix:** Ask Mail.app for the rendered HTML directly via AppleScript (`html content of selected message`) instead of parsing raw RFC822 source. Fall back to plain text on failure.

### 13. AppleScript dispatched on global queue can block
- **File:** `IRENE/IRENE/Features/Mail/MailBridge.swift:245-265`
- **Issue:** `NSAppleScript.executeAndReturnError` runs synchronously; if Mail.app is hung, the dispatched task blocks indefinitely.
- **Fix:** Add a timeout via `DispatchWorkItem.cancel()` pattern, or move script execution behind an `actor` with a configurable timeout.

### 14. iOS Mail bridge is fully stubbed
- **File:** `IRENE/IRENE/Features/Mail/MailBridge.swift:408-428`
- **Issue:** All operations throw or no-op on iOS. The Mail tab is currently dead on iPhone/iPad.
- **Fix:** Either hide the Mail module on iOS, or wire up `MFMailComposeViewController` (compose only) + an explicit "Mail not available on iOS" empty state.

---

## App-Availability Checks (NEW)

### 15. Calendar.app / Mail.app: prompt to open if not running
- **Files:**
  - `IRENE/IRENE/Features/Calendar/CalendarViewModel.swift` (and any direct EventKit calls)
  - `IRENE/IRENE/Features/Mail/MailBridge.swift` (AppleScript entry points)
- **Issue:** AppleScript automation against Mail.app and EventKit operations against Calendar silently fail or throw cryptic errors when the host app isn't running.
- **Desired behavior:** Before issuing the first AppleScript / EventKit call in a session, check whether the target app is running. If not, present a sheet/alert: "IRENE needs to open Calendar/Mail to continue. Open it now?" → Cancel / Open. On Open, launch the app via `NSWorkspace.shared.openApplication(at:)` (or `bundleIdentifier` lookup) and wait for it to become active before retrying.
- **Implementation notes:**
  - Use `NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.mail")` / `"com.apple.iCal"` to detect.
  - Centralize the check so both modules share the same prompt path (e.g., a small `AppLauncher` helper in `Core/Platform/`).
  - Persist a "don't ask again, always open" preference in `VaultConfiguration` if desired.

---

## Chat Formatting (NEW)

### 16. LLM responses not rendered as Markdown
- **Files:**
  - `IRENE/IRENE/Features/Chat/ChatBubbleView.swift`
  - `IRENE/IRENE/Features/Chat/ChatView.swift`
- **Issue:** Anthropic responses come back in Markdown (headings, lists, bold, code blocks, fenced code) but the chat bubble renders them as plain text. Code, lists, and emphasis are lost.
- **Desired behavior:** Render assistant messages as Markdown. Keep the user's own messages as plain text (or render them as Markdown too — TBD).
- **Implementation notes:**
  - The project already depends on `swift-markdown 0.4.0+` and there's an existing `MarkdownRendererView` in `Features/Notes/`. Reuse or factor it into `SharedUI/`.
  - Streaming consideration: assistant text arrives chunk-by-chunk via `AsyncThrowingStream`. Render incrementally — re-parsing the full markdown on every chunk is fine for typical message sizes, but debounce to ~50ms if it gets janky.
  - Code blocks should support copy-to-clipboard.
  - Inline code (\`like this\`) should use a monospace style from `Core/Typography/`.

---

## Editor Polish

### 17. Find/Replace lacks regex
- **File:** `IRENE/IRENE/Features/Notes/Editor/` (FindReplace bar/coordinator)
- **Issue:** Plain-text search only.
- **Fix:** Add a "regex" toggle; use `NSRegularExpression`. Surface invalid regex with a non-blocking inline error.

### 18. Line number gutter not clickable
- **File:** `IRENE/IRENE/Features/Notes/Editor/LineNumberGutterView.swift`
- **Issue:** Gutter renders numbers but clicking does nothing.
- **Fix:** Override `mouseDown`, compute target line from `convert(_:to:)` + line height, set `selectedRange` on the text view.

---

## Recording / Transcription

### 19. Transcription has no segment timing
- **File:** `IRENE/IRENE/Features/Recording/TranscriptionService.swift:82-87`
- **Issue:** All recognized text flattened into a single segment — can't click a transcript line and seek the audio.
- **Fix:** Use `SFTranscriptionSegment` to capture per-word `timestamp` + `duration`. Group by sentence or speaker turn.

### 20. No speaker diarization
- **Issue:** System+mic capture is the obvious meeting use case, but the merged track loses the channel distinction.
- **Fix (cheap):** Tag each sample stream's transcription separately ("You" vs "Other") before merging the audio. The current `readPCMSamples` flow could fork into two parallel transcription tasks before mixing.

---

## LLM Provider

### 21. OpenAI and Grok providers unimplemented
- **File:** `IRENE/IRENE/Core/LLM/LLMProvider.swift:23-25`
- **Issue:** `defaultModels` returns `[]`; no `OpenAIProvider` or `GrokProvider` types exist.
- **Fix:** Add both. They mirror `AnthropicProvider` structure (HTTP + SSE streaming). OpenAI Chat Completions and xAI Chat Completions APIs.

### 22. No tool use / function calling
- **Issue:** With IRENE's data model (notes, todos, reminders, calendar, mail), tool use is the unlock that turns chat from a sidebar into an assistant.
- **Fix:** Define a tool registry in `Core/LLM/`. Initial tools: `createSticky`, `createTodo`, `createReminder`, `createCalendarEvent`, `searchNotes`. Wire to existing ViewModels.

---

## Config / Build

### 23. `@unchecked Sendable` undermines strict concurrency
- See item #10. Listed separately because the project explicitly enables `SWIFT_STRICT_CONCURRENCY: complete` in `IRENE/project.yml`.
