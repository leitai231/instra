@testable import Instra
import Foundation
import Testing

// SettingsStore is @MainActor and requires NSApplication run loop,
// so we test its pure logic via the models and TranslationConfiguration directly.

@Suite("HotKeyConflictDetection")
struct HotKeyConflictDetectionTests {
    // Mirror the conflict detection logic from SettingsStore
    private func detectConflict(
        copy: HotKeyPreset,
        show: HotKeyPreset,
        polish: HotKeyPreset
    ) -> String? {
        let presets = [
            (TranslationAction.copy, copy),
            (TranslationAction.show, show),
            (TranslationAction.polish, polish),
        ]
        for i in presets.indices {
            for j in (i + 1)..<presets.count {
                if presets[i].1 == presets[j].1 {
                    return "\(presets[i].0.title) and \(presets[j].0.title) cannot use the same shortcut."
                }
            }
        }
        return nil
    }

    @Test("no conflict when all presets differ")
    func noConflict() {
        #expect(detectConflict(copy: .controlCommandT, show: .controlCommandS, polish: .controlCommandP) == nil)
    }

    @Test("detects conflict between copy and show")
    func conflictCopyShow() {
        let msg = detectConflict(copy: .controlCommandT, show: .controlCommandT, polish: .controlCommandP)
        #expect(msg != nil)
        #expect(msg!.contains("Translate & Copy"))
        #expect(msg!.contains("Translate & Show"))
    }

    @Test("detects conflict between copy and polish")
    func conflictCopyPolish() {
        let msg = detectConflict(copy: .controlCommandT, show: .controlCommandS, polish: .controlCommandT)
        #expect(msg != nil)
        #expect(msg!.contains("Translate & Copy"))
        #expect(msg!.contains("Polish & Copy"))
    }

    @Test("detects conflict between show and polish")
    func conflictShowPolish() {
        let msg = detectConflict(copy: .controlCommandT, show: .controlCommandS, polish: .controlCommandS)
        #expect(msg != nil)
        #expect(msg!.contains("Translate & Show"))
        #expect(msg!.contains("Polish & Copy"))
    }

    @Test("detects first conflict when multiple exist")
    func multipleConflicts() {
        let msg = detectConflict(copy: .controlCommandT, show: .controlCommandT, polish: .controlCommandT)
        #expect(msg != nil)
        // Should detect copy-show first (lowest index pair)
        #expect(msg!.contains("Translate & Copy"))
        #expect(msg!.contains("Translate & Show"))
    }
}

@Suite("TranslationConfiguration")
struct TranslationConfigurationTests {
    @Test("configuration holds correct values")
    func correctValues() {
        let config = TranslationConfiguration(
            apiKey: "sk-test",
            model: "gpt-4.1-mini",
            languageA: "Chinese (Simplified)",
            languageB: "English",
            tone: .natural
        )
        #expect(config.apiKey == "sk-test")
        #expect(config.model == "gpt-4.1-mini")
        #expect(config.languageA == "Chinese (Simplified)")
        #expect(config.languageB == "English")
        #expect(config.tone == .natural)
    }

    @Test("configuration with different tones")
    func differentTones() {
        for tone in TranslationTone.allCases {
            let config = TranslationConfiguration(
                apiKey: "key",
                model: "model",
                languageA: "A",
                languageB: "B",
                tone: tone
            )
            #expect(config.tone == tone)
        }
    }
}
