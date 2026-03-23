import AppKit
import SwiftUI

@MainActor
final class ReadingPanelController: NSObject {
    private let viewModel = ReadingPanelViewModel()
    private var panel: ReadingPanel?
    private var hostingView: NSHostingView<ReadingPanelView>?
    private var dismissHandler: (() -> Void)?
    private var isDismissing = false

    func show(
        text: String,
        onCopy: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        let screen = targetScreen()
        let maxHeight = screen.visibleFrame.height * 0.6
        // 92 = vertical padding (24×2) + button row (~44)
        let bodyMaxHeight = max(140, maxHeight - 92)

        dismissHandler = onDismiss
        viewModel.text = text
        viewModel.onCopy = onCopy

        ensurePanel(bodyMaxHeight: bodyMaxHeight)
        updateRootView(bodyMaxHeight: bodyMaxHeight)
        positionPanel(on: screen, maxHeight: maxHeight)
        panel?.makeKeyAndOrderFront(nil)
    }

    func hide(shouldRestoreFocus: Bool = true) {
        guard let panel else {
            if !shouldRestoreFocus {
                dismissHandler = nil
            }
            return
        }

        dismissPanel(panel, shouldRestoreFocus: shouldRestoreFocus)
    }

    private func ensurePanel(bodyMaxHeight: CGFloat) {
        guard panel == nil else {
            updateRootView(bodyMaxHeight: bodyMaxHeight)
            return
        }

        let hostingView = NSHostingView(
            rootView: ReadingPanelView(viewModel: viewModel, bodyMaxHeight: bodyMaxHeight)
        )
        let panel = ReadingPanel(
            contentRect: NSRect(x: 0, y: 0, width: ReadingPanelView.panelWidth, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.delegate = self
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.onCancel = { [weak self] in
            self?.hide()
        }
        panel.contentView = hostingView

        self.panel = panel
        self.hostingView = hostingView
    }

    private func updateRootView(bodyMaxHeight: CGFloat) {
        hostingView?.rootView = ReadingPanelView(viewModel: viewModel, bodyMaxHeight: bodyMaxHeight)
        hostingView?.layoutSubtreeIfNeeded()
    }

    private func positionPanel(on screen: NSScreen, maxHeight: CGFloat) {
        guard let panel, let hostingView else {
            return
        }

        let fittingSize = hostingView.fittingSize
        let height = min(maxHeight, max(180, fittingSize.height))
        let frame = screen.visibleFrame
        let x = frame.midX - ReadingPanelView.panelWidth / 2
        let y = frame.midY - height / 2

        panel.setFrame(
            NSRect(x: x, y: y, width: ReadingPanelView.panelWidth, height: height),
            display: true
        )
    }

    private func dismissPanel(_ panel: NSPanel, shouldRestoreFocus: Bool) {
        guard !isDismissing else {
            return
        }

        isDismissing = true
        let onDismiss = shouldRestoreFocus ? dismissHandler : nil
        dismissHandler = nil
        panel.orderOut(nil)
        isDismissing = false
        onDismiss?()
    }

    private func targetScreen() -> NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first {
            return screen
        }

        preconditionFailure("No screen available for reading panel.")
    }
}

extension ReadingPanelController: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel else {
            return
        }

        dismissPanel(panel, shouldRestoreFocus: true)
    }
}

@MainActor
private final class ReadingPanelViewModel: ObservableObject {
    @Published var text = ""
    var onCopy: (() -> Void)?
}

private final class ReadingPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
    }
}

private struct ReadingPanelView: View {
    static let panelWidth: CGFloat = 480

    @ObservedObject var viewModel: ReadingPanelViewModel
    let bodyMaxHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScrollView(.vertical, showsIndicators: true) {
                Text(viewModel.text)
                    .font(.system(size: 20))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, maxHeight: bodyMaxHeight, alignment: .topLeading)

            HStack {
                Spacer()
                Button("Copy") {
                    viewModel.onCopy?()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("c", modifiers: .command)
            }
        }
        .padding(24)
        .frame(width: Self.panelWidth, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 22, x: 0, y: 18)
    }
}
