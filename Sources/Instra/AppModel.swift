import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var isAccessibilityGranted = false
    @Published private(set) var isHotKeyRegistered = true
    @Published private(set) var isBusy = false
    @Published private(set) var statusMessage = "Ready to translate the current selection."
    @Published private(set) var hotKeyRegistrationMessages: [TranslationAction: String] = [:]
    @Published private(set) var lastFailureMessage: String?
    @Published private(set) var lastTranslatedPreview: String?

    let settings: SettingsStore

    private let permissionsManager: PermissionsManager
    private let selectionCaptureService: SelectionCaptureService
    private let translationService: OpenAITranslationService
    private let clipboardService: ClipboardService
    private let feedbackCenter: FeedbackCenter
    private let hotKeyManager: GlobalHotKeyManager
    private let readingPanelController: ReadingPanelController
    private let settingsWindowController: SettingsWindowController

    private var cancellables = Set<AnyCancellable>()
    private var permissionTimer: Timer?
    private var workspaceActivationObserver: NSObjectProtocol?
    private var lastExternalApplication: NSRunningApplication?
    private var lastSuccessMessage: String?

    init(
        settings: SettingsStore = SettingsStore(),
        permissionsManager: PermissionsManager = PermissionsManager(),
        translationService: OpenAITranslationService = OpenAITranslationService(),
        clipboardService: ClipboardService = ClipboardService(),
        feedbackCenter: FeedbackCenter = FeedbackCenter(),
        hotKeyManager: GlobalHotKeyManager = GlobalHotKeyManager(),
        readingPanelController: ReadingPanelController = ReadingPanelController(),
        settingsWindowController: SettingsWindowController = SettingsWindowController()
    ) {
        self.settings = settings
        self.permissionsManager = permissionsManager
        self.selectionCaptureService = SelectionCaptureService(permissionsManager: permissionsManager)
        self.translationService = translationService
        self.clipboardService = clipboardService
        self.feedbackCenter = feedbackCenter
        self.hotKeyManager = hotKeyManager
        self.readingPanelController = readingPanelController
        self.settingsWindowController = settingsWindowController

        hotKeyManager.onTrigger = { [weak self] action in
            Task { @MainActor [weak self] in
                switch action {
                case .copy:
                    await self?.translateAndCopy()
                case .show:
                    await self?.translateAndShow()
                }
            }
        }

        Publishers.CombineLatest(settings.$copyHotKeyPreset, settings.$showHotKeyPreset)
            .dropFirst()
            .sink { [weak self] _, _ in
                self?.applyHotKeyRegistrations(showFeedback: true)
            }
            .store(in: &cancellables)

        observeWorkspaceActivation()
        start()
    }

    private func start() {
        applyHotKeyRegistrations(showFeedback: false)
        refreshPermissions()
        feedbackCenter.prepareNotifications()
        startPermissionPolling()

        if needsSetupAttention {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self.showSettings()
            }
        }
    }

    var menuBarSymbolName: String {
        if isBusy {
            return "arrow.triangle.2.circlepath.circle.fill"
        }
        if hasHotKeyIssues || lastFailureMessage != nil {
            return "exclamationmark.triangle.fill"
        }
        return "globe"
    }

    var copyHotKeyDescription: String {
        settings.copyHotKeyPreset.title
    }

    var showHotKeyDescription: String {
        settings.showHotKeyPreset.title
    }

    var needsSetupAttention: Bool {
        !isAccessibilityGranted || settings.translationConfiguration == nil || !isHotKeyRegistered
    }

    var hotKeyConflictMessage: String? {
        settings.hotKeyConflictMessage
    }

    func refreshPermissions() {
        isAccessibilityGranted = permissionsManager.isAccessibilityGranted()
        if !isBusy, lastFailureMessage == nil {
            statusMessage = setupStatusMessage()
        }
    }

    func requestAccessibilityAccess() {
        permissionsManager.requestAccessibilityPrompt()
        refreshPermissions()
    }

    func openAccessibilitySettings() {
        permissionsManager.openAccessibilitySettings()
    }

    func showSettings() {
        settingsWindowController.show(model: self, settings: settings)
    }

    func clearErrorState() {
        lastFailureMessage = nil
        statusMessage = setupStatusMessage()
    }

    func hotKeyRegistrationMessage(for action: TranslationAction) -> String? {
        hotKeyRegistrationMessages[action]
    }

    func isHotKeyRegistered(for action: TranslationAction) -> Bool {
        settings.hotKeyConflictMessage == nil && hotKeyRegistrationMessages[action] == nil
    }

    func translateAndCopy() async {
        await performTranslation(for: .copy)
    }

    func translateAndShow() async {
        await performTranslation(for: .show)
    }

    func translateSelection() async {
        await translateAndCopy()
    }

    private func performTranslation(for action: TranslationAction) async {
        guard !isBusy else {
            feedbackCenter.showWorking("Instra is already processing the previous request.")
            return
        }

        guard let configuration = settings.translationConfiguration else {
            handleFailure(TranslationPipelineError.apiKeyMissing)
            showSettings()
            return
        }

        guard isAccessibilityGranted else {
            handleFailure(TranslationPipelineError.accessibilityPermissionMissing)
            showSettings()
            return
        }

        readingPanelController.hide(shouldRestoreFocus: false)
        isBusy = true
        lastFailureMessage = nil
        statusMessage = "Capturing selected text…"
        feedbackCenter.showWorking("Capturing selected text…")

        do {
            await prepareSelectionCaptureContext()
            let selectedText = try await selectionCaptureService.captureSelectedText()
            statusMessage = "Translating…"
            feedbackCenter.showWorking("Translating…")

            let translatedText = try await translationService.translate(selectedText, configuration: configuration)
            updateTranslatedPreview(with: translatedText)

            switch action {
            case .copy:
                try completeCopyAction(with: translatedText)
            case .show:
                showReadingPanel(with: translatedText)
            }
        } catch {
            handleFailure(error)
        }

        isBusy = false
        if lastFailureMessage == nil {
            statusMessage = setupStatusMessage()
        }
    }

    private func startPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshPermissions()
            }
        }
    }

    private func observeWorkspaceActivation() {
        updateLastExternalApplication(NSWorkspace.shared.frontmostApplication)
        workspaceActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }

            Task { @MainActor [weak self] in
                self?.updateLastExternalApplication(application)
            }
        }
    }

    private func updateLastExternalApplication(_ application: NSRunningApplication?) {
        guard let application, application.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return
        }
        lastExternalApplication = application
    }

    private func prepareSelectionCaptureContext() async {
        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        updateLastExternalApplication(frontmostApplication)

        if let frontmostApplication,
           frontmostApplication.processIdentifier == currentProcessIdentifier,
           let applicationToRestore = lastExternalApplication,
           !applicationToRestore.isTerminated {
            applicationToRestore.activate(options: [])
            try? await Task.sleep(nanoseconds: 220_000_000)
            return
        }

        // Let menu dismissal and hotkey modifier release settle before we inspect the selection.
        try? await Task.sleep(nanoseconds: 120_000_000)
    }

    private func handleFailure(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        lastFailureMessage = message
        statusMessage = message
        feedbackCenter.showFailure(title: "Instra", message: message)
    }

    private var hasHotKeyIssues: Bool {
        settings.hotKeyConflictMessage != nil || !hotKeyRegistrationMessages.isEmpty
    }

    private func applyHotKeyRegistrations(showFeedback: Bool) {
        hotKeyManager.unregisterAll()
        hotKeyRegistrationMessages = [:]

        if let conflictMessage = settings.hotKeyConflictMessage {
            isHotKeyRegistered = false
            statusMessage = conflictMessage
            if showFeedback {
                feedbackCenter.showFailure(title: "Instra Shortcut Conflict", message: conflictMessage)
            }
            return
        }

        for action in TranslationAction.allCases {
            let preset = settings.hotKeyPreset(for: action)
            switch hotKeyManager.register(preset, for: action) {
            case .success:
                continue
            case .failure(let error):
                hotKeyRegistrationMessages[action] = error.localizedDescription
                if showFeedback {
                    feedbackCenter.showFailure(
                        title: "\(action.title) Shortcut Unavailable",
                        message: error.localizedDescription
                    )
                }
            }
        }

        isHotKeyRegistered = hotKeyRegistrationMessages.isEmpty
        if !isBusy, lastFailureMessage == nil {
            statusMessage = setupStatusMessage()
        }
    }

    private func completeCopyAction(with translatedText: String) throws {
        guard clipboardService.write(translatedText) else {
            throw TranslationPipelineError.clipboardWriteFailed
        }

        lastFailureMessage = nil
        lastSuccessMessage = TranslationAction.copy.successStatusMessage
        statusMessage = TranslationAction.copy.successStatusMessage
        feedbackCenter.showSuccess("Translated text is ready to paste.")
    }

    private func showReadingPanel(with translatedText: String) {
        lastFailureMessage = nil
        lastSuccessMessage = TranslationAction.show.successStatusMessage
        statusMessage = TranslationAction.show.successStatusMessage
        feedbackCenter.hideWorking()

        let applicationToRestore = lastExternalApplication
        NSApplication.shared.activate(ignoringOtherApps: true)
        readingPanelController.show(
            text: translatedText,
            onCopy: { [weak self] in
                self?.copyFromReadingPanel(translatedText)
            },
            onDismiss: { [weak self] in
                self?.restoreApplicationAfterReadingPanelDismiss(applicationToRestore)
            }
        )
    }

    private func copyFromReadingPanel(_ translatedText: String) {
        guard clipboardService.write(translatedText) else {
            handleFailure(TranslationPipelineError.clipboardWriteFailed)
            return
        }

        lastFailureMessage = nil
        lastSuccessMessage = TranslationAction.copy.successStatusMessage
        statusMessage = TranslationAction.copy.successStatusMessage
        feedbackCenter.showSuccess("Translated text is ready to paste.")
    }

    private func restoreApplicationAfterReadingPanelDismiss(_ application: NSRunningApplication?) {
        guard let application, !application.isTerminated else {
            return
        }

        application.activate(options: [])
    }

    private func updateTranslatedPreview(with translatedText: String) {
        let preview = translatedText.replacingOccurrences(of: "\n", with: " ")
        lastTranslatedPreview = String(preview.prefix(120))
    }

    private func setupStatusMessage() -> String {
        if let conflictMessage = settings.hotKeyConflictMessage {
            return conflictMessage
        }

        for action in TranslationAction.allCases {
            if let message = hotKeyRegistrationMessages[action] {
                return message
            }
        }

        if !isAccessibilityGranted {
            return TranslationPipelineError.accessibilityPermissionMissing.localizedDescription
        }
        if settings.translationConfiguration == nil {
            return TranslationPipelineError.apiKeyMissing.localizedDescription
        }
        return lastSuccessMessage ?? "Ready to translate the current selection."
    }
}
