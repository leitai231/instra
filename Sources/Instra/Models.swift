import AppKit
import Carbon
import Foundation

enum TranslationTone: String, CaseIterable, Identifiable {
    case natural
    case polite
    case concise

    var id: String { rawValue }

    var title: String {
        switch self {
        case .natural:
            return "Natural"
        case .polite:
            return "Polite"
        case .concise:
            return "Concise"
        }
    }

    var promptDescriptor: String {
        switch self {
        case .natural:
            return "Natural conversational language appropriate for everyday messages."
        case .polite:
            return "Warm, polite language that still feels human and not overly formal."
        case .concise:
            return "Short, direct language with minimal filler."
        }
    }
}

enum TranslationAction: String, CaseIterable, Identifiable {
    case copy
    case show
    case polish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .copy:
            return "Translate & Copy"
        case .show:
            return "Translate & Show"
        case .polish:
            return "Polish & Copy"
        }
    }

    var successStatusMessage: String {
        switch self {
        case .copy:
            return "Last translation copied to clipboard."
        case .show:
            return "Last translation shown in reading panel."
        case .polish:
            return "Polished text copied to clipboard."
        }
    }

    var hotKeyID: UInt32 {
        switch self {
        case .copy:
            return 1
        case .show:
            return 2
        case .polish:
            return 3
        }
    }
}

enum HotKeyPreset: String, CaseIterable, Identifiable {
    case controlCommandT
    case controlCommandS
    case controlOptionT
    case controlCommandE
    case controlCommandP

    var id: String { rawValue }

    var title: String {
        switch self {
        case .controlCommandT:
            return "Control + Command + T"
        case .controlCommandS:
            return "Control + Command + S"
        case .controlOptionT:
            return "Control + Option + T"
        case .controlCommandE:
            return "Control + Command + E"
        case .controlCommandP:
            return "Control + Command + P"
        }
    }

    var keyCode: UInt32 {
        switch self {
        case .controlCommandT, .controlOptionT:
            return UInt32(kVK_ANSI_T)
        case .controlCommandS:
            return UInt32(kVK_ANSI_S)
        case .controlCommandE:
            return UInt32(kVK_ANSI_E)
        case .controlCommandP:
            return UInt32(kVK_ANSI_P)
        }
    }

    var carbonModifiers: UInt32 {
        switch self {
        case .controlCommandT, .controlCommandS, .controlCommandE, .controlCommandP:
            return UInt32(controlKey | cmdKey)
        case .controlOptionT:
            return UInt32(controlKey | optionKey)
        }
    }

    var eventModifiers: NSEvent.ModifierFlags {
        switch self {
        case .controlCommandT, .controlCommandS, .controlCommandE, .controlCommandP:
            return [.control, .command]
        case .controlOptionT:
            return [.control, .option]
        }
    }
}

struct TranslationConfiguration {
    let apiKey: String
    let model: String
    let languageA: String
    let languageB: String
    let tone: TranslationTone
}

enum HotKeyRegistrationError: LocalizedError, Equatable {
    case alreadyInUse(HotKeyPreset)
    case systemError(status: OSStatus, preset: HotKeyPreset)

    var errorDescription: String? {
        switch self {
        case .alreadyInUse(let preset):
            return "The shortcut \(preset.title) is already in use by another app. Choose a different shortcut in Settings."
        case .systemError(let status, let preset):
            return "Instra could not register \(preset.title). System status: \(status)."
        }
    }
}

struct WhitespaceEnvelope {
    let leading: String
    let body: String
    let trailing: String

    static func extract(from text: String) -> WhitespaceEnvelope {
        let leading = String(text.prefix { $0.isWhitespace })
        let trailing = String(text.reversed().prefix { $0.isWhitespace }.reversed())
        let start = text.index(text.startIndex, offsetBy: leading.count)
        let end = text.index(text.endIndex, offsetBy: -trailing.count)
        let body = start <= end ? String(text[start..<end]) : ""
        return WhitespaceEnvelope(leading: leading, body: body, trailing: trailing)
    }

    func rebuild(with translatedBody: String) -> String {
        leading + translatedBody + trailing
    }
}

enum TranslationPipelineError: LocalizedError {
    case accessibilityPermissionMissing
    case apiKeyMissing
    case emptySelection
    case captureFailed(String)
    case translationFailed(String)
    case clipboardWriteFailed
    case secureContextBlocked

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionMissing:
            return "Accessibility permission is required before Instra can read selected text."
        case .apiKeyMissing:
            return "Add an OpenAI API key in Settings before translating."
        case .emptySelection:
            return "No translatable text was captured from the current selection."
        case .captureFailed(let detail):
            return detail
        case .translationFailed(let detail):
            return detail
        case .clipboardWriteFailed:
            return "Instra could not write the translated text to the clipboard."
        case .secureContextBlocked:
            return "No text was selected, or the current app blocked text capture."
        }
    }
}
