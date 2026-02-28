import Foundation
import SwiftUI

@MainActor
final class FluxusViewModel: ObservableObject {
    @Published var config: FluxusConfig = .default()
    @Published var appearance: AppAppearance = .system {
        didSet {
            appearance.persist()
            AppAppearanceManager.apply(appearance)
        }
    }
    @Published var hasAcknowledgedWarning: Bool
    @Published var acknowledgmentChecked: Bool = false

    @Published var isBusy: Bool = false
    @Published var statusMessage: String = ""
    @Published var statusIsError: Bool = false

    @Published var simulationOutput: SimulationOutput?
    @Published var simulationCandidates: [CandidateRecord] = []
    @Published var sortOrder: [KeyPathComparator<CandidateRecord>] = [
        KeyPathComparator(\.path, order: .forward)
    ]

    @Published var historyOutput: RunOutput?
    @Published private(set) var launchAgentLoaded: Bool = false

    init() {
        hasAcknowledgedWarning = Self.firstRunAcknowledgementOverride()
            ?? UserDefaults.standard.bool(forKey: FluxusViewModelConstants.firstRunDefaultsKey)
        appearance = AppAppearance.load()
        AppAppearanceManager.apply(appearance)
        loadInitialState()
        refreshLaunchAgentStatus()
    }

    func refreshLaunchAgentStatus() {
        launchAgentLoaded = LaunchAgentManager().isLoaded()
    }
}
