import AppKit
import Combine
import SwiftUI
import UserNotifications

@MainActor
final class FeedbackCenter {
    private let hudController = HUDWindowController()
    private let notificationCenter = UNUserNotificationCenter.current()

    func prepareNotifications() {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func showWorking(_ message: String) {
        hudController.show(message: message, style: .working, autoHideAfter: nil)
    }

    func showSuccess(_ message: String) {
        hudController.show(message: message, style: .success, autoHideAfter: 1.0)
    }

    func showFailure(title: String, message: String) {
        hudController.show(message: message, style: .failure, autoHideAfter: 2.0)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { _ in }
    }

    func hideWorking() {
        hudController.hide()
    }
}

@MainActor
private final class HUDWindowController {
    private let viewModel = HUDViewModel()
    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    func show(message: String, style: HUDStyle, autoHideAfter seconds: Double?) {
        hideTask?.cancel()
        ensurePanel()
        viewModel.message = message
        viewModel.style = style
        positionPanel()
        panel?.alphaValue = 1
        panel?.orderFrontRegardless()

        if let seconds {
            hideTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(seconds))
                await MainActor.run {
                    self?.hide()
                }
            }
        }
    }

    func hide() {
        hideTask?.cancel()
        panel?.orderOut(nil)
    }

    private func ensurePanel() {
        guard panel == nil else {
            return
        }

        let hostingView = NSHostingView(rootView: HUDView(viewModel: viewModel))
        let fittingSize = hostingView.fittingSize
        hostingView.frame = NSRect(origin: .zero, size: fittingSize)

        let panel = NSPanel(
            contentRect: hostingView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = hostingView

        self.panel = panel
    }

    private func positionPanel() {
        guard let panel else {
            return
        }

        let targetFrame = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
        let x = targetFrame.midX - panel.frame.width / 2
        let y = targetFrame.maxY - panel.frame.height - 16
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

@MainActor
private final class HUDViewModel: ObservableObject {
    @Published var message = ""
    @Published var style: HUDStyle = .working
}

private enum HUDStyle: Equatable {
    case working
    case success
    case failure

    var iconName: String {
        switch self {
        case .working:
            return "arrow.triangle.2.circlepath"
        case .success:
            return "checkmark.circle.fill"
        case .failure:
            return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .working:
            return .blue
        case .success:
            return .green
        case .failure:
            return .red
        }
    }
}

private struct HUDView: View {
    @ObservedObject var viewModel: HUDViewModel

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(viewModel.style.tint.opacity(0.16))
                    .frame(width: 32, height: 32)

                if viewModel.style == .working {
                    ProgressView()
                        .controlSize(.small)
                        .tint(viewModel.style.tint)
                } else {
                    Image(systemName: viewModel.style.iconName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(viewModel.style.tint)
                }
            }

            Text(title)
                .font(.headline)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .fixedSize()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var title: String {
        switch viewModel.style {
        case .working:
            return "Translating"
        case .success:
            return "Copied to Clipboard"
        case .failure:
            return "Translation Failed"
        }
    }
}
