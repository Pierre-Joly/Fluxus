import SwiftUI

struct MainDashboardView: View {
    @ObservedObject var viewModel: FluxusViewModel

    @State private var selectedSection: DashboardSection? = .overview
    @State private var selectedCandidateID: CandidateRecord.ID?

    private var resolvedSection: DashboardSection {
        selectedSection ?? .overview
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                ForEach(DashboardSection.allCases) { section in
                    HStack {
                        Label(section.title, systemImage: section.systemImage)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                    .tag(section)
                    .accessibilityIdentifier("sidebar-section-\(section.rawValue)")
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 210, ideal: 230)
            .safeAreaInset(edge: .bottom) {
                sidebarFooter
                    .padding(12)
            }
        } detail: {
            VStack(alignment: .leading, spacing: 18) {
                Text(resolvedSection.title)
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("main-section-title")

                dashboardSectionContent(for: resolvedSection)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.background)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Save") {
                    Task { await viewModel.saveAndApplySchedule() }
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(viewModel.isBusy)

                Button("Run Now") {
                    Task { await viewModel.runNow() }
                }
                .disabled(viewModel.isBusy)
            }

        }
        .overlay {
            if viewModel.isBusy {
                ZStack {
                    Color.black.opacity(0.08)
                        .ignoresSafeArea()
                    VStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Working…")
                            .font(.headline)
                    }
                    .padding(18)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !viewModel.statusMessage.isEmpty {
                StatusBannerView(
                    message: viewModel.statusMessage,
                    isError: viewModel.statusIsError,
                    onDismiss: viewModel.clearStatus
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
        }
        .frame(minWidth: 800, minHeight: 480)
    }

    @ViewBuilder
    private func dashboardSectionContent(for section: DashboardSection) -> some View {
        switch section {
        case .overview:
            paneScrollView(accessibilityIdentifier: "pane-scroll-overview") {
                OverviewPane(viewModel: viewModel, scheduleDateBinding: scheduleDateBinding)
                    .accessibilityIdentifier("pane-overview")
            }
        case .rules:
            paneScrollView(accessibilityIdentifier: "pane-scroll-rules") {
                RulesPane(viewModel: viewModel)
                    .accessibilityIdentifier("pane-rules")
            }
        case .simulation:
            paneScrollView(accessibilityIdentifier: "pane-scroll-simulation") {
                SimulationPane(
                    viewModel: viewModel,
                    selectedCandidateID: $selectedCandidateID
                )
                .accessibilityIdentifier("pane-simulation")
            }
        case .history:
            paneScrollView(accessibilityIdentifier: "pane-scroll-history") {
                HistoryPane(viewModel: viewModel)
                    .accessibilityIdentifier("pane-history")
            }
        }
    }

    private func paneScrollView<Content: View>(
        accessibilityIdentifier: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView(.vertical) {
            content()
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.trailing, 2)
        }
        .accessibilityIdentifier(accessibilityIdentifier)
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var scheduleDateBinding: Binding<Date> {
        Binding {
            let calendar = Calendar.current
            return calendar.date(
                bySettingHour: viewModel.config.schedule.hour,
                minute: viewModel.config.schedule.minute,
                second: 0,
                of: Date()
            ) ?? Date()
        } set: { newDate in
            let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
            viewModel.config.schedule.hour = components.hour ?? 0
            viewModel.config.schedule.minute = components.minute ?? 0
        }
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scheduler")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.launchAgentLoaded ? Color.green : Color.secondary)
                    .frame(width: 8, height: 8)
                Text(viewModel.launchAgentLoaded ? "Agent loaded" : "Agent not loaded")
                    .font(.subheadline)
            }

            Text("\(viewModel.config.roots.count) target\(viewModel.config.roots.count == 1 ? "" : "s") configured")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }
}
