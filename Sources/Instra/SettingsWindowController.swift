import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private var windowController: NSWindowController?

    func show(model: AppModel, settings: SettingsStore) {
        let contentView = SettingsView(model: model, settings: settings)

        if let hostingController = windowController?.contentViewController as? NSHostingController<SettingsView> {
            hostingController.rootView = contentView
        } else {
            let hostingController = NSHostingController(rootView: contentView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Instra Settings"
            window.setContentSize(NSSize(width: 520, height: 560))
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = false
            window.isReleasedWhenClosed = false
            window.center()
            window.setFrameAutosaveName("InstraSettingsWindow")
            let controller = NSWindowController(window: window)
            controller.shouldCascadeWindows = true
            windowController = controller
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        windowController?.showWindow(nil)
        windowController?.window?.makeKeyAndOrderFront(nil)
    }
}
