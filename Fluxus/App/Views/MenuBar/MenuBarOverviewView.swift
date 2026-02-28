import AppKit
import SwiftUI

struct MenuBarOverviewView: View {
    @ObservedObject var viewModel: FluxusViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                MenuBarHeaderCard(enabled: viewModel.config.enabled)

                MenuBarAutomationCard(
                    enabled: enabledBinding,
                    isToggleDisabled: viewModel.isBusy || !viewModel.hasAcknowledgedWarning,
                    scheduleText: scheduleText,
                    targetCount: viewModel.config.roots.count,
                    launchAgentLoaded: viewModel.launchAgentLoaded,
                    guidanceMessage: guidanceMessage
                )

                MenuBarQuickActionsCard(
                    isBusy: viewModel.isBusy,
                    isActionDisabled: actionButtonsDisabled,
                    onSimulation: { Task { await viewModel.runSimulationNow() } },
                    onRunNow: { Task { await viewModel.runNow() } }
                )

                MenuBarUtilityRow(
                    onOpenDashboard: openDashboard,
                    onQuit: quitApp
                )

                MenuBarStatusCard(
                    isError: viewModel.statusIsError,
                    message: viewModel.statusMessage.isEmpty ? historyLine : viewModel.statusMessage,
                    onDismiss: statusDismissAction
                )
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 360)
        .frame(maxHeight: 520)
        .scrollIndicators(.visible)
        .animation(.easeInOut(duration: 0.18), value: viewModel.isBusy)
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { viewModel.config.enabled },
            set: { newValue in
                viewModel.config.enabled = newValue
                Task { await viewModel.saveAndApplySchedule() }
            }
        )
    }

    private var actionButtonsDisabled: Bool {
        viewModel.isBusy || !viewModel.hasAcknowledgedWarning || !viewModel.config.hasTargets
    }

    private var guidanceMessage: MenuBarGuidanceMessage? {
        if !viewModel.hasAcknowledgedWarning {
            return MenuBarGuidanceMessage(
                text: "Open dashboard and confirm first-run warning to enable automation.",
                icon: "hand.raised.fill",
                color: .orange
            )
        }

        if viewModel.config.enabled && !viewModel.config.hasTargets {
            return MenuBarGuidanceMessage(
                text: "No targets configured. Add at least one folder in Rules.",
                icon: "folder.badge.questionmark",
                color: .orange
            )
        }

        return nil
    }

    private var historyLine: String {
        guard let output = viewModel.historyOutput else {
            return "Ready"
        }
        return "History: \(output.processedCount) file(s), \(viewModel.formatBytes(output.totalBytes))."
    }

    private var statusDismissAction: (() -> Void)? {
        viewModel.statusMessage.isEmpty ? nil : { viewModel.clearStatus() }
    }

    private var scheduleText: String {
        String(format: "%02d:%02d", viewModel.config.schedule.hour, viewModel.config.schedule.minute)
    }

    private func openDashboard() {
        openWindow(id: AppWindow.main)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func quitApp() {
        NSApp.terminate(nil)
    }
}

struct MenuBarGuidanceMessage {
    let text: String
    let icon: String
    let color: Color
}
