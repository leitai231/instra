# Instra Kickoff Design

Date: 2026-03-17
Status: Draft

## 1. Summary

Instra is a small macOS utility for a single, focused workflow:

1. The user writes text in their native language in any app.
2. The user selects the text.
3. The user presses a global shortcut.
4. Instra sends the selected text to an LLM for translation.
5. When translation finishes, Instra writes the result to the clipboard and shows lightweight completion feedback.
6. The user pastes the translated text with `Command + V`.

The product goal is not to become a full writing assistant. The goal is to make cross-app translation feel instant, reliable, and low-friction.

## 2. Problem

The user often writes outbound messages in apps like Messages, email, notes, browsers, or arbitrary text editors. They want to think and draft in their native language, then quickly translate the selected text into the target language without switching apps, opening a chat window, or manually copying text into a separate tool.

Current pain points:

- Context switching breaks writing flow.
- Existing translation tools are often browser-first, app-specific, or too heavyweight.
- Replacing text inline across arbitrary macOS apps is fragile.

## 3. Product Principles

- Cross-app first: work from any reasonably standard text input surface on macOS.
- One-shot interaction: select, trigger, wait, paste.
- Stability over magic: translation result goes to clipboard; the app does not auto-insert text into the source app in MVP.
- Fast feedback: clear success and failure feedback without creating notification spam.
- Personal-tool simplicity: minimal UI, minimal configuration, strong defaults.
- Quiet by default: success states should feel lightweight; only failures should interrupt.

## 4. MVP Scope

### In Scope

- Menu bar macOS app
- Global keyboard shortcut
- Read currently selected text
- Translate selected text with an LLM API
- Put translated result onto clipboard
- Show lightweight progress and success feedback plus actionable failure notifications
- Settings for:
  - API key
  - target language
  - translation style or prompt mode
  - keyboard shortcut

### Out of Scope

- Automatic replacement of selected text in the source app
- Conversation history or translation archive
- Multi-step editing UI
- OCR for images
- Offline translation
- Team sync, cloud account system, or multi-device state

## 5. Primary User Flow

### Happy Path

1. User selects text in any app.
2. User presses the configured global shortcut.
3. Instra captures the selected text.
4. Instra shows a lightweight in-progress state, likely via a transient HUD and menu bar state.
5. Instra sends the text to the configured translation backend.
6. Instra receives translated text.
7. Instra writes the translated text to the system clipboard.
8. Instra shows lightweight success feedback such as a transient HUD.
9. User pastes manually where needed.

### Failure Cases

- No selected text found
- Accessibility permission missing
- Source app does not expose selection
- Network request fails
- LLM returns empty or malformed output
- Clipboard write fails

For MVP, each failure should produce a clear notification with one actionable hint.

## 6. Technical Approach

### App Shape

- Native macOS menu bar app
- Built with `Swift` and `SwiftUI`
- Background-first UX with a small settings window

This shape matches the product: always available, low overhead, no dock-centric workflow.

### Core Components

#### 6.1 Shortcut Manager

Responsibilities:

- Register and listen for a global shortcut
- Prevent duplicate invocation while a translation job is running
- Allow user customization in settings

Implementation options:

- `KeyboardShortcuts` package for faster implementation
- Or Carbon/AppKit event APIs if full control is needed

Recommendation: start with a proven shortcut package unless product constraints appear later.

#### 6.2 Selection Capture Service

Responsibilities:

- Read the currently selected text from the frontmost app
- Return a normalized string for translation

Recommended strategy:

1. First attempt via macOS Accessibility APIs
2. If that fails, transparently fall back to simulated copy flow

Accessibility-first is cleaner because it avoids mutating the clipboard before translation.

Fallback copy flow:

- Save current clipboard contents
- Record current `NSPasteboard.changeCount`
- Simulate `Command + C`
- Wait for clipboard change with short polling and a bounded timeout
- Read copied text only after the pasteboard actually changes
- Restore prior clipboard after capture succeeds or fails
- Treat timeout or secure-input refusal as a capture failure

This fallback improves compatibility with editors that do not expose selected text cleanly through Accessibility.

#### 6.3 Translation Service

Responsibilities:

- Accept source text plus translation config
- Call the model provider
- Return translated text only

Design choice:

- Define a provider protocol from day one
- Start with OpenAI as the first provider implementation
- Optimize the first provider choice for latency and integration simplicity rather than model breadth

Example interface:

- `translate(text: String, targetLanguage: String, tone: Tone) async throws -> String`

This keeps the app flexible if the backend changes later.

Translation output contract:

- Prompt the model to return only translated text with no preamble, labels, or quotes
- Preserve intentional leading and trailing whitespace or newlines from the original selection
- Normalize malformed or empty responses into explicit failures rather than guessing

#### 6.4 Clipboard Service

Responsibilities:

- Write translated result to `NSPasteboard`
- Optionally keep track of whether the write succeeded

MVP behavior:

- Always write translated text to clipboard on success
- Do not attempt inline insertion back into the source app

#### 6.5 Feedback Service

Responsibilities:

- Show lightweight in-progress state
- Show lightweight success confirmation
- Show actionable failures

Implementation:

- Transient HUD for in-progress and success states
- Menu bar busy state while a translation is running
- `UserNotifications` for failure states only

Success should not generate persistent system notifications by default. This keeps the tool usable at high frequency.

#### 6.6 Settings and Persistence

Settings:

- API key
- Target language
- Prompt style
- Shortcut
- Optional advanced diagnostics

Persistence:

- Use `UserDefaults` for ordinary settings
- Store API key in Keychain

## 7. Permissions and Privacy

### Required Permissions

- Accessibility permission
  - Needed to inspect focused UI elements and selection state
- Notification permission
  - Needed for failure feedback

### Onboarding Requirements

- First-run experience should detect missing Accessibility permission immediately
- Provide a one-click action to open the macOS Accessibility settings pane
  - Use `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility` when supported
- Poll or refresh permission state so the app can continue without requiring a restart
- Make it explicit that text is sent to an external model provider for translation

### Privacy Expectations

- Selected text is sent to the configured LLM provider for translation
- The app should explicitly state this in onboarding and settings
- API keys must be stored in Keychain, not plain text config

Privacy hardening direction:

- Per-app exclusion list for apps where the user does not want text captured
- Minimum denylist for obvious sensitive apps such as password managers

## 8. UX Decisions

### Why Clipboard Instead of Auto-Replacing Text

Clipboard output is the right MVP tradeoff because it is:

- More reliable across arbitrary macOS apps
- Easier to reason about
- Less likely to destroy user input accidentally
- Compatible with the user's existing paste habit

Auto-replace can be explored later, but it should not be part of the first version.

### Suggested MVP Defaults

- Target language: English
- Style: natural conversational
- Shortcut: a single memorable global combo defined during onboarding
- Fallback copy capture: enabled by default and transparent to the user
- Successful translations overwrite the clipboard; no clipboard history management in MVP
- Success feedback: transient HUD plus clipboard update

### Quiet Feedback Strategy

- Use transient in-app feedback for in-progress and success states
- Reserve system notifications for failures that need user attention
- Avoid spamming Notification Center for normal successful translations

## 9. Risks and Unknowns

### Biggest Technical Risk

Cross-app text selection capture is the least deterministic part of the system.

Known variability:

- Some apps expose selected text well through Accessibility
- Some editors expose selection inconsistently
- Terminal-like or custom-rendered apps may fail entirely

Mitigation:

- Build capture logic as an isolated module
- Log failure reasons locally for debugging
- Support fallback copy mode
- Test early against a matrix of common apps

### Secondary Risks

- Global shortcut conflicts with other tools
- Translation latency feels too slow for "instant utility" expectations
- Clipboard edge cases if fallback capture temporarily touches clipboard state
- Accidental trigger in sensitive apps or secure input contexts

## 10. App Test Matrix

MVP should be tested at minimum in:

- Messages
- Notes
- Mail
- Safari text areas
- Chrome text areas
- VS Code
- TextEdit
- Slack
- Secure-input or password-manager refusal behavior

Goal:

- Confirm selection capture success rate
- Confirm notification behavior
- Confirm clipboard write reliability
- Confirm correct refusal behavior in sensitive contexts

## 11. Implementation Plan

### Phase 1: Skeleton App

- Create menu bar app shell
- Add settings window
- Add shortcut registration
- Add permission onboarding with deep link to Accessibility settings
- Add live permission state detection

### Phase 2: Selection Capture

- Implement Accessibility-based selected text capture
- Add transparent fallback copy mode with `NSPasteboard.changeCount` waiting and timeout handling
- Add diagnostics for failure states
- Validate on core test matrix

### Phase 3: Translation Pipeline

- Add provider abstraction
- Implement first low-latency LLM backend
- Add request state handling and timeout behavior
- Enforce strict translated-text-only output contract
- Preserve leading and trailing whitespace when rebuilding final output

### Phase 4: Clipboard and Feedback

- Write translated text to clipboard
- Add transient HUD and menu bar busy state
- Use system notifications for failure states only
- Prevent concurrent jobs

### Phase 5: Hardening

- Add minimum sensitive-app denylist and secure-input refusal behavior
- Expand app compatibility checks
- Polish error copy and settings

## 12. Suggested Initial Architecture

Suggested modules:

- `App`
- `Shortcut`
- `Permissions`
- `SelectionCapture`
- `Translation`
- `Clipboard`
- `Feedback`
- `Settings`

Suggested top-level runtime flow:

1. Shortcut fired
2. Guard against active job
3. Capture selected text
4. Validate non-empty text
5. Translate
6. Write clipboard
7. Emit feedback result

## 13. Success Criteria for MVP

The MVP is successful if:

- The user can trigger translation from several everyday apps without opening another window
- The app reliably copies translated output to the clipboard
- Failures are clear and recoverable
- End-to-end flow feels fast enough for frequent daily use
- Success feedback remains quiet enough for repeated daily use

## 14. Working Decisions

Working decisions:

- OpenAI is the first provider target; provider abstraction keeps later swaps cheap
- Fallback copy mode is enabled by default and should be transparent to the user
- Successful translations overwrite the clipboard in MVP; explicit clipboard history management is out of scope
- MVP uses a fixed target language chosen in settings
- Progress and success use a transient HUD plus menu bar state; failures use system notifications
- Sensitive-app protection starts with a minimal denylist during hardening rather than a large policy system

## 15. Recommendation

Proceed with a narrow MVP:

- Menu bar app
- Global shortcut
- Selection capture with Accessibility-first strategy
- LLM translation
- Clipboard output
- Quiet success feedback and actionable failure notifications

That version is small enough to build quickly, but complete enough to validate whether the workflow is truly useful in daily communication.
