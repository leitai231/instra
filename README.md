# Instra

A lightweight macOS menu bar translation app. Select text anywhere, press a shortcut, get the translation instantly.

## How It Works

1. Select text in any app
2. Press a global shortcut
3. Translation lands on your clipboard (or appears in a reading panel)
4. Paste where you need it

No app switching. No browser tabs. Just select → translate → paste.

## Features

- **Translate & Copy** — translates selected text, copies result to clipboard
- **Translate & Show** — translates and displays result in a floating reading panel
- **Auto language detection** — detects input language, translates to the other
- **Works in any app** — Accessibility API with smart clipboard fallback
- **Global shortcuts** — configurable hotkeys, works system-wide
- **Three tones** — Natural, Polite, or Concise translation style
- **Menu bar native** — lives in the menu bar, never in your way
- **Secure** — API key stored in macOS Keychain

## Requirements

- macOS 14.0+ (Sonoma)
- Swift 6.1+ toolchain
- OpenAI API key

## Quick Start

```bash
# Build and launch
./Scripts/compile_and_run.sh
```

On first launch:

1. Grant **Accessibility** permission when prompted
2. Open **Settings** and enter your OpenAI API key
3. Choose your language pair (default: Chinese Simplified ↔ English)
4. Select text anywhere and press `Ctrl + Cmd + T`

## Default Shortcuts

| Action | Shortcut |
|--------|----------|
| Translate & Copy | `Ctrl + Cmd + T` |
| Translate & Show | `Ctrl + Cmd + S` |

Shortcuts can be changed in Settings (4 presets available).

## Build

```bash
# Debug build
swift build

# Production build + launch
./Scripts/compile_and_run.sh

# Universal binary (arm64 + x86_64)
./Scripts/compile_and_run.sh --release-universal
```

### Code Signing

Without configuration, the app is signed ad-hoc. For proper signing:

```bash
cp signing.env.example signing.env
# Edit signing.env with your codesigning identity
```

Find available identities:

```bash
security find-identity -v -p codesigning
```

## Architecture

```
Sources/Instra/
├── AppModel.swift              # Central coordinator
├── OpenAITranslationService.swift  # OpenAI API integration
├── SelectionCaptureService.swift   # Text capture (A11y + clipboard fallback)
├── GlobalHotKeyManager.swift       # Carbon + NSEvent hotkeys
├── SettingsStore.swift             # UserDefaults + Keychain
├── ReadingPanelController.swift    # Floating reading panel
├── FeedbackCenter.swift            # HUD notifications
├── PermissionsManager.swift        # Accessibility permission handling
├── ClipboardService.swift          # Clipboard I/O
└── Views/
    ├── MenuBarView.swift           # Menu bar UI
    ├── SettingsView.swift          # Settings window
    └── ReadingPanelView.swift      # Reading panel content
```

## License

GPL-2.0 — see [LICENSE](LICENSE) for details.
