import Foundation

enum ConfigStore {
    static func loadConfig(from configPath: String) throws -> FluxusConfig {
        let expandedPath = FluxusPaths.expandTilde(in: configPath)
        let url = URL(fileURLWithPath: expandedPath)
        let data = try Data(contentsOf: url)
        return try FluxusJSON.decoder.decode(FluxusConfig.self, from: data)
    }

    static func loadDefaultConfig() throws -> FluxusConfig {
        let configURL = FluxusPaths.configURL
        if FileManager.default.fileExists(atPath: configURL.path) {
            return try loadConfig(from: configURL.path)
        }

        let defaultConfig = FluxusConfig.default()
        try save(config: defaultConfig, to: configURL.path)
        return defaultConfig
    }

    static func save(config: FluxusConfig, to configPath: String) throws {
        let expandedPath = FluxusPaths.expandTilde(in: configPath)
        let url = URL(fileURLWithPath: expandedPath)
        try FluxusPaths.ensureParentDirectory(for: url)
        let data = try FluxusJSON.encoder.encode(config)
        try data.write(to: url, options: .atomic)
    }

    static func loadLastRun() throws -> RunOutput {
        let data = try Data(contentsOf: FluxusPaths.lastRunURL)
        return try FluxusJSON.decoder.decode(RunOutput.self, from: data)
    }

    static func saveLastRun(_ output: RunOutput) throws {
        try FluxusPaths.ensureParentDirectory(for: FluxusPaths.lastRunURL)
        let data = try FluxusJSON.encoder.encode(output)
        try data.write(to: FluxusPaths.lastRunURL, options: .atomic)
    }

    static func loadSchedulerState() throws -> SchedulerState {
        let data = try Data(contentsOf: FluxusPaths.schedulerStateURL)
        return try FluxusJSON.decoder.decode(SchedulerState.self, from: data)
    }

    static func saveSchedulerState(_ state: SchedulerState) throws {
        try FluxusPaths.ensureParentDirectory(for: FluxusPaths.schedulerStateURL)
        let data = try FluxusJSON.encoder.encode(state)
        try data.write(to: FluxusPaths.schedulerStateURL, options: .atomic)
    }

    static func markPolicyActivated(at date: Date = Date()) throws {
        let state = SchedulerState(policyActivatedAt: FluxusJSON.isoString(date))
        try saveSchedulerState(state)
    }
}
