import Foundation

extension FluxusViewModel {
    func saveAndApplySchedule() async {
        if config.enabled && !hasAcknowledgedWarning {
            config.enabled = false
            setStatus("Automatic cleanup remains disabled until first-run warning is acknowledged.", isError: true)
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            let requestedEnabled = config.enabled
            var normalizedConfig = try FluxusConfigNormalizer.normalize(
                config,
                requireRoots: false,
                validatePaths: requestedEnabled
            )

            let autoDisabledNoTargets = requestedEnabled && !normalizedConfig.hasTargets
            if autoDisabledNoTargets {
                normalizedConfig.enabled = false
            }

            let configPath = FluxusViewModelConstants.configPath
            try ConfigStore.save(config: normalizedConfig, to: configPath)
            config = normalizedConfig

            let helperPath = try FluxusctlRunner().helperURL().path
            let message = try LaunchAgentManager().installOrUpdate(
                helperPath: helperPath,
                configPath: configPath,
                schedule: normalizedConfig.schedule,
                enabled: normalizedConfig.canSchedule
            )

            refreshLaunchAgentStatus()
            if autoDisabledNoTargets {
                setStatus("No targets configured. Automatic cleanup was disabled.", isError: false)
            } else {
                setStatus(message, isError: false)
            }
        } catch {
            setStatus("Failed to apply Agent configuration : \(error.localizedDescription)", isError: true)
        }
    }

    func runSimulationNow() async {
        isBusy = true
        defer { isBusy = false }

        do {
            let normalizedConfig = try FluxusConfigNormalizer.normalize(config, requireRoots: true, validatePaths: true)
            let configPath = FluxusViewModelConstants.configPath
            try ConfigStore.save(config: normalizedConfig, to: configPath)
            config = normalizedConfig

            let result = try FluxusctlRunner().run(arguments: ["--simulate", "--config", configPath])
            guard !result.stdout.isEmpty else {
                throw NSError(
                    domain: "Fluxus",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Fluxusctl returned empty stdout."]
                )
            }

            let decoded = try FluxusJSON.decoder.decode(SimulationOutput.self, from: Data(result.stdout.utf8))
            simulationOutput = decoded
            simulationCandidates = decoded.candidates
            applySortOrder()

            if result.exitCode == 0 {
                setStatus(
                    "Dry run complete: \(decoded.candidateCount) files, \(formatBytes(decoded.totalBytes)).",
                    isError: false
                )
            } else {
                let detail = result.stderr.isEmpty ? "Validation issues were reported." : result.stderr
                setStatus("Dry run finished with warnings: \(detail)", isError: true)
            }
        } catch {
            setStatus("Dry run failed: \(error.localizedDescription)", isError: true)
        }
    }

    func runNow() async {
        isBusy = true
        defer { isBusy = false }

        do {
            let normalizedConfig = try FluxusConfigNormalizer.normalize(config, requireRoots: true, validatePaths: true)
            let configPath = FluxusViewModelConstants.configPath
            try ConfigStore.save(config: normalizedConfig, to: configPath)
            config = normalizedConfig

            let result = try FluxusctlRunner().run(arguments: ["--run", "--config", configPath])
            guard !result.stdout.isEmpty else {
                throw NSError(
                    domain: "Fluxus",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Fluxusctl returned empty stdout."]
                )
            }

            let decoded = try FluxusJSON.decoder.decode(RunOutput.self, from: Data(result.stdout.utf8))
            historyOutput = decoded

            if result.exitCode == 0 {
                setStatus("Cleanup run complete: \(decoded.processedCount) files processed.", isError: false)
            } else {
                let detail = result.stderr.isEmpty ? "See history report for details." : result.stderr
                setStatus("Cleanup run finished with errors: \(detail)", isError: true)
            }
        } catch {
            setStatus("Cleanup run failed: \(error.localizedDescription)", isError: true)
        }
    }

    func refreshHistoryFromDisk() {
        do {
            historyOutput = try ConfigStore.loadLastRun()
            setStatus("History report refreshed.", isError: false)
        } catch {
            setStatus("No history report found.", isError: true)
        }
    }
}
