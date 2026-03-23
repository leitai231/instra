@testable import Instra
import Testing

@Suite("TranslationAction")
struct TranslationActionTests {
    @Test("all cases have unique hotKeyIDs")
    func uniqueHotKeyIDs() {
        let ids = TranslationAction.allCases.map(\.hotKeyID)
        #expect(Set(ids).count == ids.count)
    }

    @Test("all cases have non-empty titles")
    func nonEmptyTitles() {
        for action in TranslationAction.allCases {
            #expect(!action.title.isEmpty)
        }
    }

    @Test("all cases have non-empty success messages")
    func nonEmptySuccessMessages() {
        for action in TranslationAction.allCases {
            #expect(!action.successStatusMessage.isEmpty)
        }
    }

    @Test("polish action has correct hotKeyID")
    func polishHotKeyID() {
        #expect(TranslationAction.polish.hotKeyID == 3)
    }
}

@Suite("HotKeyPreset")
struct HotKeyPresetTests {
    @Test("all presets have unique raw values")
    func uniqueRawValues() {
        let rawValues = HotKeyPreset.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("all presets have non-empty titles")
    func nonEmptyTitles() {
        for preset in HotKeyPreset.allCases {
            #expect(!preset.title.isEmpty)
        }
    }

    @Test("controlCommandP has correct key code for P")
    func controlCommandPKeyCode() {
        #expect(HotKeyPreset.controlCommandP.keyCode == 35) // kVK_ANSI_P = 0x23 = 35
    }

    @Test("presets with same modifier have matching carbon and event modifiers")
    func modifierConsistency() {
        let cmdControlPresets: [HotKeyPreset] = [
            .controlCommandT, .controlCommandS, .controlCommandE, .controlCommandP,
        ]
        for preset in cmdControlPresets {
            #expect(preset.eventModifiers.contains(.control))
            #expect(preset.eventModifiers.contains(.command))
        }

        #expect(HotKeyPreset.controlOptionT.eventModifiers.contains(.control))
        #expect(HotKeyPreset.controlOptionT.eventModifiers.contains(.option))
    }
}

@Suite("TranslationTone")
struct TranslationToneTests {
    @Test("all tones have non-empty prompt descriptors")
    func nonEmptyPromptDescriptors() {
        for tone in TranslationTone.allCases {
            #expect(!tone.promptDescriptor.isEmpty)
        }
    }
}

@Suite("TranslationPipelineError")
struct TranslationPipelineErrorTests {
    @Test("all errors have localized descriptions")
    func localizedDescriptions() {
        let errors: [TranslationPipelineError] = [
            .accessibilityPermissionMissing,
            .apiKeyMissing,
            .emptySelection,
            .captureFailed("test"),
            .translationFailed("test"),
            .clipboardWriteFailed,
            .secureContextBlocked,
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }
}
