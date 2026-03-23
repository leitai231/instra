import AppKit
import ApplicationServices
import Carbon
import Foundation

struct SelectionCaptureService {
    private let permissionsManager: PermissionsManager

    init(permissionsManager: PermissionsManager) {
        self.permissionsManager = permissionsManager
    }

    func captureSelectedText() async throws -> String {
        if let accessibilityText = captureUsingAccessibility(), !accessibilityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Accessibility API from some apps (browsers, outliners, rich-text
            // editors) returns text without line breaks between block elements.
            // Clipboard copy (Cmd-C) typically retains this structure, so try it
            // when the accessibility result looks flattened.
            if !accessibilityText.contains(where: \.isNewline) && accessibilityText.count > 50 {
                if let richerText = try? await captureUsingCopyFallback(),
                   richerText.contains(where: \.isNewline) {
                    return richerText
                }
            }
            return accessibilityText
        }

        guard permissionsManager.isAccessibilityGranted() else {
            throw TranslationPipelineError.accessibilityPermissionMissing
        }

        return try await captureUsingCopyFallback()
    }

    private func captureUsingAccessibility() -> String? {
        guard permissionsManager.isAccessibilityGranted() else {
            return nil
        }

        let systemWide = AXUIElementCreateSystemWide()
        if let focused = copyElementAttribute(.focusedUIElement, from: systemWide),
           let selected = copyStringAttribute(.selectedText, from: focused),
           !selected.isEmpty {
            return selected
        }

        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            return nil
        }

        let application = AXUIElementCreateApplication(pid)
        if let focused = copyElementAttribute(.focusedUIElement, from: application),
           let selected = copyStringAttribute(.selectedText, from: focused),
           !selected.isEmpty {
            return selected
        }

        return nil
    }

    private func copyElementAttribute(_ attribute: AXAttribute, from element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute.rawValue as CFString, &value)
        guard status == .success, let value else {
            return nil
        }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func copyStringAttribute(_ attribute: AXAttribute, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute.rawValue as CFString, &value)
        guard status == .success else {
            return nil
        }
        return value as? String
    }

    private func captureUsingCopyFallback() async throws -> String {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(from: pasteboard)
        let baselineChangeCount = pasteboard.changeCount

        try triggerCopyShortcut()
        let changed = try await waitForPasteboardChange(pasteboard: pasteboard, baselineChangeCount: baselineChangeCount)

        defer {
            snapshot.restore(to: pasteboard)
        }

        guard changed else {
            throw TranslationPipelineError.secureContextBlocked
        }

        guard let text = pasteboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslationPipelineError.emptySelection
        }

        return text
    }

    private func triggerCopyShortcut() throws {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            throw TranslationPipelineError.captureFailed("Instra could not create a keyboard event source for fallback copy capture.")
        }

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }

    private func waitForPasteboardChange(
        pasteboard: NSPasteboard,
        baselineChangeCount: Int
    ) async throws -> Bool {
        let timeoutNanoseconds: UInt64 = 600_000_000
        let pollNanoseconds: UInt64 = 50_000_000
        let started = DispatchTime.now().uptimeNanoseconds

        while DispatchTime.now().uptimeNanoseconds - started < timeoutNanoseconds {
            if pasteboard.changeCount != baselineChangeCount {
                return true
            }
            try await Task.sleep(nanoseconds: pollNanoseconds)
        }

        return false
    }
}

private enum AXAttribute: String {
    case focusedUIElement = "AXFocusedUIElement"
    case selectedText = "AXSelectedText"
}

private struct PasteboardSnapshot {
    private let items: [PasteboardItemSnapshot]

    init(from pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map(PasteboardItemSnapshot.init)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else {
            return
        }

        let restoredItems = items.map(\.materializedItem)
        pasteboard.writeObjects(restoredItems)
    }
}

private struct PasteboardItemSnapshot {
    let values: [(String, Data)]

    init(item: NSPasteboardItem) {
        values = item.types.compactMap { type in
            guard let data = item.data(forType: type) else {
                return nil
            }
            return (type.rawValue, data)
        }
    }

    var materializedItem: NSPasteboardItem {
        let item = NSPasteboardItem()
        for (type, data) in values {
            item.setData(data, forType: NSPasteboard.PasteboardType(type))
        }
        return item
    }
}
