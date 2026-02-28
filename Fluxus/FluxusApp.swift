import SwiftUI

@main
struct FluxusApp: App {
    @StateObject private var viewModel = FluxusViewModel()

    var body: some Scene {
        WindowGroup(id: AppWindow.main) {
            ContentView(viewModel: viewModel)
                .onAppear {
                    AppAppearanceManager.apply(viewModel.appearance)
                }
        }
        .defaultSize(width: 880, height: 560)
        .commands {
            FluxusAppCommands()
        }

        MenuBarExtra {
            MenuBarOverviewView(viewModel: viewModel)
                .onAppear {
                    AppAppearanceManager.apply(viewModel.appearance)
                }
        } label: {
            MenuBarStatusLabel()
        }
        .menuBarExtraStyle(.window)

        Settings {
            FluxusSettingsView(viewModel: viewModel)
                .onAppear {
                    AppAppearanceManager.apply(viewModel.appearance)
                }
        }
    }
}

enum AppWindow {
    static let main = "main-window"
}

private struct MenuBarStatusLabel: View {
    var body: some View {
        Image(systemName: "water.waves")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .accessibilityLabel("Fluxus")
    }
}

private struct FluxusAppCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Dashboard Window") {
                openWindow(id: AppWindow.main)
            }
            .keyboardShortcut("n", modifiers: .command)
        }
    }
}
