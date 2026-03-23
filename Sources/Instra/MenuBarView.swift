import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            statusCard
            actionButtons
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 360)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Instra")
                .font(.title3.weight(.semibold))
            Text("Copy with \(model.copyHotKeyDescription), or open the reading panel with \(model.showHotKeyDescription).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(model.needsSetupAttention ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                    .frame(width: 10, height: 10)
                Text(model.needsSetupAttention ? "Setup needed" : "Ready")
                    .font(.headline)
            }

            Text(model.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let preview = model.lastTranslatedPreview, !preview.isEmpty {
                Text("Last result: \(preview)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var actionButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task { await model.translateAndCopy() }
            } label: {
                Label(model.isBusy ? "Translating…" : "Translate & Copy", systemImage: model.isBusy ? "arrow.triangle.2.circlepath" : "doc.on.clipboard")
            }
            .keyboardShortcut(.return)
            .disabled(model.isBusy)

            Button {
                Task { await model.translateAndShow() }
            } label: {
                Label("Translate & Show", systemImage: "text.magnifyingglass")
            }
            .disabled(model.isBusy)

            Button {
                model.showSettings()
            } label: {
                Label(model.needsSetupAttention ? "Complete Setup" : "Settings", systemImage: "gearshape")
            }

            if !model.isAccessibilityGranted {
                Button {
                    model.requestAccessibilityAccess()
                } label: {
                    Label("Request Accessibility Access", systemImage: "hand.raised")
                }
            }

            Button(role: .destructive) {
                NSApp.terminate(nil)
            } label: {
                Label("Quit Instra", systemImage: "power")
            }
        }
        .buttonStyle(.borderless)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Shortcuts")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Translate & Copy: \(model.copyHotKeyDescription)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Translate & Show: \(model.showHotKeyDescription)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
