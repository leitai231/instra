import Combine
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var languageA: String {
        didSet { defaults.set(languageA, forKey: Keys.languageA) }
    }

    @Published var languageB: String {
        didSet { defaults.set(languageB, forKey: Keys.languageB) }
    }

    @Published var tone: TranslationTone {
        didSet { defaults.set(tone.rawValue, forKey: Keys.tone) }
    }

    @Published var copyHotKeyPreset: HotKeyPreset {
        didSet { defaults.set(copyHotKeyPreset.rawValue, forKey: Keys.copyHotKeyPreset) }
    }

    @Published var showHotKeyPreset: HotKeyPreset {
        didSet { defaults.set(showHotKeyPreset.rawValue, forKey: Keys.showHotKeyPreset) }
    }

    @Published var polishHotKeyPreset: HotKeyPreset {
        didSet { defaults.set(polishHotKeyPreset.rawValue, forKey: Keys.polishHotKeyPreset) }
    }

    @Published var openAIModel: String {
        didSet { defaults.set(openAIModel, forKey: Keys.openAIModel) }
    }

    @Published var apiKey: String {
        didSet { persistAPIKey() }
    }

    @Published private(set) var lastPersistenceError: String?

    private let defaults: UserDefaults
    private let keychain: KeychainStore
    private let keychainService = "com.blackkingbar.instra"
    private let keychainAccount = "openai_api_key"

    init(
        defaults: UserDefaults = .standard,
        keychain: KeychainStore = KeychainStore()
    ) {
        self.defaults = defaults
        self.keychain = keychain

        languageA = defaults.string(forKey: Keys.languageA) ?? "Chinese (Simplified)"
        languageB = defaults.string(forKey: Keys.languageB) ?? "English"
        tone = TranslationTone(rawValue: defaults.string(forKey: Keys.tone) ?? "") ?? .natural
        let legacyHotKeyPreset = defaults.string(forKey: Keys.legacyHotKeyPreset) ?? ""
        copyHotKeyPreset = HotKeyPreset(rawValue: defaults.string(forKey: Keys.copyHotKeyPreset) ?? legacyHotKeyPreset) ?? .controlCommandT
        showHotKeyPreset = HotKeyPreset(rawValue: defaults.string(forKey: Keys.showHotKeyPreset) ?? "") ?? .controlCommandS
        polishHotKeyPreset = HotKeyPreset(rawValue: defaults.string(forKey: Keys.polishHotKeyPreset) ?? "") ?? .controlCommandP
        openAIModel = defaults.string(forKey: Keys.openAIModel) ?? "gpt-4.1-mini"
        apiKey = (try? keychain.load(service: keychainService, account: keychainAccount)) ?? ""
    }

    var translationConfiguration: TranslationConfiguration? {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            return nil
        }

        let model = openAIModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = languageA.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = languageB.trimmingCharacters(in: .whitespacesAndNewlines)
        return TranslationConfiguration(
            apiKey: trimmedKey,
            model: model.isEmpty ? "gpt-4.1-mini" : model,
            languageA: a.isEmpty ? "Chinese (Simplified)" : a,
            languageB: b.isEmpty ? "English" : b,
            tone: tone
        )
    }

    var hotKeyConflictMessage: String? {
        let presets = [
            (TranslationAction.copy, copyHotKeyPreset),
            (TranslationAction.show, showHotKeyPreset),
            (TranslationAction.polish, polishHotKeyPreset),
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

    func hotKeyPreset(for action: TranslationAction) -> HotKeyPreset {
        switch action {
        case .copy:
            return copyHotKeyPreset
        case .show:
            return showHotKeyPreset
        case .polish:
            return polishHotKeyPreset
        }
    }

    private func persistAPIKey() {
        do {
            let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                try keychain.delete(service: keychainService, account: keychainAccount)
            } else {
                try keychain.save(trimmed, service: keychainService, account: keychainAccount)
            }
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = error.localizedDescription
        }
    }

    private enum Keys {
        static let languageA = "settings.languageA"
        static let languageB = "settings.languageB"
        static let tone = "settings.tone"
        static let copyHotKeyPreset = "settings.copyHotKeyPreset"
        static let showHotKeyPreset = "settings.showHotKeyPreset"
        static let legacyHotKeyPreset = "settings.hotKeyPreset"
        static let polishHotKeyPreset = "settings.polishHotKeyPreset"
        static let openAIModel = "settings.openAIModel"
    }
}
