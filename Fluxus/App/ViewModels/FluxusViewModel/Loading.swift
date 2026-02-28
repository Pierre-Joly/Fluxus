import Foundation

extension FluxusViewModel {
    func loadInitialState() {
        do {
            config = try ConfigStore.loadDefaultConfig()
            migrateLegacyPrefilledFirstRunConfigIfNeeded()

            if config.enabled && !config.hasTargets {
                config.enabled = false
                try? ConfigStore.save(config: config, to: FluxusViewModelConstants.configPath)
                _ = try? LaunchAgentManager().uninstall()
                setStatus("Automatic cleanup was disabled because no targets are configured.", isError: false)
            }
        } catch {
            config = FluxusConfig.default()
            setStatus("Failed to load config.json: \(error.localizedDescription)", isError: true)
        }

        do {
            historyOutput = try ConfigStore.loadLastRun()
        } catch {
            historyOutput = nil
        }

        refreshLaunchAgentStatus()
    }
}

private extension FluxusViewModel {
    func migrateLegacyPrefilledFirstRunConfigIfNeeded() {
        guard !hasAcknowledgedWarning else {
            return
        }
        guard looksLikeLegacyPrefilledDefaults(config) else {
            return
        }

        config.roots = []
        try? ConfigStore.save(config: config, to: FluxusViewModelConstants.configPath)
    }

    func looksLikeLegacyPrefilledDefaults(_ value: FluxusConfig) -> Bool {
        guard value.roots.count == 2 else {
            return false
        }

        let first = value.roots[0]
        let second = value.roots[1]

        return first.name.lowercased() == "downloads"
            && second.name.lowercased() == "scratch"
            && first.path == "~/Downloads"
            && second.path == "~/scratch"
            && first.retentionDays == 30
            && second.retentionDays == 7
            && first.action == .trash
            && second.action == .trash
    }
}
