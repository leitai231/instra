import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            onboardingSection
            translationSection
            advancedSection
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 560)
        .padding(20)
    }

    private var onboardingSection: some View {
        Section("Setup") {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Accessibility")
                        .font(.headline)
                    Text(model.isAccessibilityGranted ? "Granted" : "Required to read selected text from other apps.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if model.isAccessibilityGranted {
                    Label("Granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    HStack(spacing: 10) {
                        Button("Prompt") {
                            model.requestAccessibilityAccess()
                        }
                        Button("Open Settings") {
                            model.openAccessibilitySettings()
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Privacy")
                    .font(.headline)
                Text("Selected text is sent to OpenAI for translation. Instra stores your API key in Keychain. Translate & Copy writes the result to the clipboard. Translate & Show opens a reading panel and only copies when you press Copy.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var translationSection: some View {
        Section("Translation") {
            SecureField("OpenAI API key", text: $settings.apiKey)
                .textFieldStyle(.roundedBorder)

            Picker("Language A", selection: $settings.languageA) {
                ForEach(Self.languages, id: \.self) { lang in
                    Text(lang).tag(lang)
                }
            }

            Picker("Language B", selection: $settings.languageB) {
                ForEach(Self.languages, id: \.self) { lang in
                    Text(lang).tag(lang)
                }
            }

            Picker("Tone", selection: $settings.tone) {
                ForEach(TranslationTone.allCases) { tone in
                    Text(tone.title).tag(tone)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                hotKeyPicker(
                    title: TranslationAction.copy.title,
                    selection: $settings.copyHotKeyPreset,
                    action: .copy
                )
                hotKeyPicker(
                    title: TranslationAction.show.title,
                    selection: $settings.showHotKeyPreset,
                    action: .show
                )
            }
            .padding(.vertical, 4)

            if let message = settings.hotKeyConflictMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private static let languages = [
        "English",
        "Chinese (Simplified)",
        "Chinese (Traditional)",
        "Japanese",
        "Korean",
        "Spanish",
        "French",
        "German",
        "Portuguese",
        "Russian",
        "Arabic",
        "Italian",
        "Thai",
        "Vietnamese",
        "Indonesian",
    ]

    private static let models: [(label: String, value: String)] = [
        ("GPT-4.1 mini — balanced", "gpt-4.1-mini"),
        ("GPT-4.1 nano — fastest", "gpt-4.1-nano"),
        ("GPT-4.1 — best quality", "gpt-4.1"),
        ("GPT-4o mini — fallback", "gpt-4o-mini"),
    ]

    private var advancedSection: some View {
        Section("Advanced") {
            Picker("OpenAI model", selection: $settings.openAIModel) {
                ForEach(Self.models, id: \.value) { model in
                    Text(model.label).tag(model.value)
                }
            }

            if let error = settings.lastPersistenceError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private func hotKeyPicker(
        title: String,
        selection: Binding<HotKeyPreset>,
        action: TranslationAction
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(title, selection: selection) {
                ForEach(HotKeyPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }

            if settings.hotKeyConflictMessage == nil {
                if let message = model.hotKeyRegistrationMessage(for: action) {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Label("\(action.title) shortcut is active.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
    }
}
