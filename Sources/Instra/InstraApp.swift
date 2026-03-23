import SwiftUI

@main
struct InstraApp: App {
    @StateObject private var model = AppModel()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            Label("Instra", systemImage: model.menuBarSymbolName)
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    model.showSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
