import SwiftUI

private struct MenuBarCardModifier: ViewModifier {
    let strokeOpacity: Double

    func body(content: Content) -> some View {
        content
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.quaternary.opacity(strokeOpacity), lineWidth: 0.6)
            )
    }
}

private extension View {
    func menuBarCard(strokeOpacity: Double = 0.5) -> some View {
        modifier(MenuBarCardModifier(strokeOpacity: strokeOpacity))
    }
}

struct MenuBarHeaderCard: View {
    let enabled: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("🌊")
                .font(.system(size: 30))
                .frame(width: 30, height: 30)
                .background(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text("Fluxus")
                    .font(.headline.weight(.semibold))
            }

            Spacer(minLength: 0)

            stateBadge(title: enabled ? "On" : "Off", color: enabled ? .green : .secondary)
        }
        .menuBarCard(strokeOpacity: 0.55)
    }

    private func stateBadge(title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.16), in: Capsule())
    }
}

struct MenuBarAutomationCard: View {
    let enabled: Binding<Bool>
    let isToggleDisabled: Bool
    let scheduleText: String
    let targetCount: Int
    let launchAgentLoaded: Bool
    let guidanceMessage: MenuBarGuidanceMessage?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Automatic Cleanup")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Toggle("", isOn: enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(.green)
                    .disabled(isToggleDisabled)
            }

            HStack(spacing: 8) {
                MenuBarStatTile(
                    title: "Schedule",
                    value: scheduleText,
                    systemImage: "clock"
                )
                MenuBarStatTile(
                    title: "Targets",
                    value: "\(targetCount)",
                    systemImage: "folder"
                )
                MenuBarStatTile(
                    title: "Agent",
                    value: launchAgentLoaded ? "Loaded" : "Idle",
                    systemImage: "antenna.radiowaves.left.and.right"
                )
            }

            if let guidanceMessage {
                HStack(spacing: 6) {
                    Image(systemName: guidanceMessage.icon)
                        .foregroundStyle(guidanceMessage.color)
                    Text(guidanceMessage.text)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .font(.caption2)
            }
        }
        .menuBarCard()
    }
}

struct MenuBarQuickActionsCard: View {
    let isBusy: Bool
    let isActionDisabled: Bool
    let onSimulation: () -> Void
    let onRunNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Actions")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 8) {
                Button(action: onSimulation) {
                    Label("Simulation", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isActionDisabled)

                Button(action: onRunNow) {
                    Label("Run Now", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.blue)
                .disabled(isActionDisabled)
            }

            if isBusy {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Working…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .menuBarCard()
    }
}

struct MenuBarUtilityRow: View {
    let onOpenDashboard: () -> Void
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onOpenDashboard) {
                Label("Open Dashboard", systemImage: "rectangle.grid.2x2")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            Spacer(minLength: 12)

            Button(action: onQuit) {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
    }
}

struct MenuBarStatusCard: View {
    let isError: Bool
    let message: String
    let onDismiss: (() -> Void)?

    init(isError: Bool, message: String, onDismiss: (() -> Void)? = nil) {
        self.isError = isError
        self.message = message
        self.onDismiss = onDismiss
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? .orange : .green)
            Text(message)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss message")
            }
        }
        .font(.caption2)
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.quaternary.opacity(0.45), lineWidth: 0.5)
        )
    }
}
