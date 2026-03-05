import Darwin
import Foundation

enum CLICommand {
    case simulation
    case run
    case runIfMissed
    case validate
}

struct CLIOptions {
    let command: CLICommand
    let configPath: String
}

enum CLIError: Error, LocalizedError {
    case invalidArguments(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments(let message):
            return message
        }
    }
}

private enum OptionalDateLoadResult {
    case missing
    case invalid
    case value(Date)
}

private struct RunIfMissedOutput: Codable, Hashable {
    let command: String
    let evaluatedAt: String
    let ran: Bool
    let reason: String
    let anchorAt: String?
    let dueAt: String?
    let run: RunOutput?
}

enum FluxusctlMain {
    static func run() {
        do {
            do {
                try FluxusPaths.ensureDirectory(FluxusPaths.appSupportDirectory)
                try FluxusPaths.ensureDirectory(FluxusPaths.logsDirectory)
            } catch {
                fputs("Fluxusctl warning: \(error.localizedDescription)\n", stderr)
            }

            let options = try parse(arguments: Array(CommandLine.arguments.dropFirst()))
            let config = try ConfigStore.loadConfig(from: options.configPath)

            let engine = CleanupEngine(logger: { message in
                let stamp = FluxusJSON.isoString(Date())
                fputs("[\(stamp)] \(message)\n", stderr)
            })

            switch options.command {
            case .validate:
                let output = engine.validate(config: config)
                try writeJSON(output)
                exit(output.valid ? EXIT_SUCCESS : EXIT_FAILURE)

            case .simulation:
                let output = engine.simulation(config: config)
                try writeJSON(output)
                exit(output.issues.isEmpty ? EXIT_SUCCESS : EXIT_FAILURE)

            case .run:
                let output = try executeRun(config: config, engine: engine)
                try writeJSON(output)
                exit(output.errorCount == 0 ? EXIT_SUCCESS : EXIT_FAILURE)

            case .runIfMissed:
                let output = try executeRunIfMissed(config: config, engine: engine)
                try writeJSON(output)
                if let run = output.run {
                    exit(run.errorCount == 0 ? EXIT_SUCCESS : EXIT_FAILURE)
                }
                exit(EXIT_SUCCESS)
            }
        } catch {
            let message = error.localizedDescription
            fputs("Fluxusctl error: \(message)\n", stderr)

            let fallback = [
                "command": "error",
                "message": message
            ]
            if let data = try? JSONSerialization.data(withJSONObject: fallback, options: [.sortedKeys]),
               let text = String(data: data, encoding: .utf8) {
                print(text)
            }

            exit(EXIT_FAILURE)
        }
    }

    private static func executeRun(config: FluxusConfig, engine: CleanupEngine) throws -> RunOutput {
        if let output = try CleanupRunLock.withExclusiveLock({
            engine.run(config: config)
        }) {
            persistLastRun(output)
            return output
        }

        let now = Date()
        return lockBusyRunOutput(config: config, at: now)
    }

    private static func executeRunIfMissed(
        config: FluxusConfig,
        engine: CleanupEngine
    ) throws -> RunIfMissedOutput {
        let now = Date()
        let nowText = FluxusJSON.isoString(now)

        guard config.enabled else {
            return skippedRunIfMissedOutput(
                at: nowText,
                reason: "automation_disabled"
            )
        }

        guard config.hasTargets else {
            return skippedRunIfMissedOutput(
                at: nowText,
                reason: "no_targets"
            )
        }

        guard config.schedule.isValid else {
            return skippedRunIfMissedOutput(
                at: nowText,
                reason: "invalid_schedule"
            )
        }

        switch loadPolicyActivatedAt() {
        case .missing:
            try? ConfigStore.markPolicyActivated(at: now)
            return skippedRunIfMissedOutput(
                at: nowText,
                reason: "initialized_policy_anchor"
            )

        case .invalid:
            try? ConfigStore.markPolicyActivated(at: now)
            return skippedRunIfMissedOutput(
                at: nowText,
                reason: "reset_invalid_policy_anchor"
            )

        case .value(let policyActivatedAt):
            let lastRunAt: Date?
            switch loadLastRunStartedAt() {
            case .missing:
                lastRunAt = nil
            case .invalid:
                try? FileManager.default.removeItem(at: FluxusPaths.lastRunURL)
                try? ConfigStore.markPolicyActivated(at: now)
                return skippedRunIfMissedOutput(
                    at: nowText,
                    reason: "reset_invalid_last_run"
                )
            case .value(let value):
                lastRunAt = value
            }

            let decision = MissedSchedulePolicy.evaluate(
                now: now,
                schedule: config.schedule,
                lastRunAt: lastRunAt,
                policyActivatedAt: policyActivatedAt
            )

            guard decision.shouldRun else {
                return skippedRunIfMissedOutput(
                    at: nowText,
                    reason: reasonString(for: decision.reason),
                    anchorAt: decision.anchorAt,
                    dueAt: decision.dueAt
                )
            }

            guard let runOutput = try CleanupRunLock.withExclusiveLock({
                engine.run(config: config)
            }) else {
                return skippedRunIfMissedOutput(
                    at: nowText,
                    reason: "already_running",
                    anchorAt: decision.anchorAt,
                    dueAt: decision.dueAt
                )
            }

            persistLastRun(runOutput)
            return RunIfMissedOutput(
                command: "run-if-missed",
                evaluatedAt: nowText,
                ran: true,
                reason: "due_and_executed",
                anchorAt: decision.anchorAt.map(FluxusJSON.isoString),
                dueAt: decision.dueAt.map(FluxusJSON.isoString),
                run: runOutput
            )
        }
    }

    private static func loadPolicyActivatedAt() -> OptionalDateLoadResult {
        if !FileManager.default.fileExists(atPath: FluxusPaths.schedulerStateURL.path) {
            return .missing
        }

        guard let state = try? ConfigStore.loadSchedulerState(),
              let activatedAt = FluxusJSON.parseISODate(state.policyActivatedAt) else {
            return .invalid
        }

        return .value(activatedAt)
    }

    private static func loadLastRunStartedAt() -> OptionalDateLoadResult {
        if !FileManager.default.fileExists(atPath: FluxusPaths.lastRunURL.path) {
            return .missing
        }

        guard let run = try? ConfigStore.loadLastRun(),
              let startedAt = FluxusJSON.parseISODate(run.startedAt) else {
            return .invalid
        }

        return .value(startedAt)
    }

    private static func persistLastRun(_ output: RunOutput) {
        do {
            try ConfigStore.saveLastRun(output)
        } catch {
            fputs("Fluxusctl warning: Failed to write last_run.json: \(error.localizedDescription)\n", stderr)
        }
    }

    private static func skippedRunIfMissedOutput(
        at evaluatedAt: String,
        reason: String,
        anchorAt: Date? = nil,
        dueAt: Date? = nil
    ) -> RunIfMissedOutput {
        RunIfMissedOutput(
            command: "run-if-missed",
            evaluatedAt: evaluatedAt,
            ran: false,
            reason: reason,
            anchorAt: anchorAt.map(FluxusJSON.isoString),
            dueAt: dueAt.map(FluxusJSON.isoString),
            run: nil
        )
    }

    private static func reasonString(for reason: MissedScheduleRunReason) -> String {
        switch reason {
        case .due:
            return "due"
        case .invalidSchedule:
            return "invalid_schedule"
        case .missingPolicyAnchor:
            return "missing_policy_anchor"
        case .notDueYet:
            return "not_due_yet"
        }
    }

    private static func lockBusyRunOutput(config: FluxusConfig, at now: Date) -> RunOutput {
        let stamp = FluxusJSON.isoString(now)
        let message = "Another cleanup run is already in progress."
        let roots = config.roots.map { root in
            RootExecutionSummary(
                name: root.name,
                path: root.path,
                retentionDays: root.retentionDays,
                action: root.action,
                candidateCount: 0,
                processedCount: 0,
                bytes: 0,
                errors: []
            )
        }

        return RunOutput(
            command: "run",
            startedAt: stamp,
            finishedAt: stamp,
            candidateCount: 0,
            processedCount: 0,
            trashedCount: 0,
            archivedCount: 0,
            skippedCount: 0,
            errorCount: 1,
            prunedDirectoryCount: 0,
            totalBytes: 0,
            roots: roots,
            topFolders: [],
            errors: [OperationError(path: "(lock)", message: message)]
        )
    }

    private static func parse(arguments: [String]) throws -> CLIOptions {
        if arguments.contains("--help") || arguments.isEmpty {
            throw CLIError.invalidArguments(usage)
        }

        // Keep --dry-run as a backward-compatible alias while preferring --simulate.
        let hasSimulation = arguments.contains("--simulate") || arguments.contains("--dry-run")
        let hasRun = arguments.contains("--run")
        let hasRunIfMissed = arguments.contains("--run-if-missed")
        let hasValidate = arguments.contains("--validate")

        let modeCount = [hasSimulation, hasRun, hasRunIfMissed, hasValidate].filter { $0 }.count
        guard modeCount == 1 else {
            throw CLIError.invalidArguments(
                "Specify exactly one of --simulate, --run, --run-if-missed, --validate\n\n\(usage)"
            )
        }

        guard let configIndex = arguments.firstIndex(of: "--config"),
              configIndex + 1 < arguments.count else {
            throw CLIError.invalidArguments("Missing --config <path>\n\n\(usage)")
        }

        let configPath = arguments[configIndex + 1]
        let command: CLICommand
        if hasSimulation {
            command = .simulation
        } else if hasRun {
            command = .run
        } else if hasRunIfMissed {
            command = .runIfMissed
        } else {
            command = .validate
        }

        return CLIOptions(command: command, configPath: configPath)
    }

    private static func writeJSON<T: Encodable>(_ value: T) throws {
        let data = try FluxusJSON.encoder.encode(value)
        guard let text = String(data: data, encoding: .utf8) else {
            throw CLIError.invalidArguments("Failed to encode JSON output")
        }
        print(text)
    }

    private static let usage = """
    Usage:
      Fluxusctl --validate --config <path>
      Fluxusctl --simulate --config <path>
      Fluxusctl --run --config <path>
      Fluxusctl --run-if-missed --config <path>
    """
}

private enum CleanupRunLock {
    static func withExclusiveLock<T>(_ operation: () throws -> T) throws -> T? {
        try FluxusPaths.ensureParentDirectory(for: FluxusPaths.runLockURL)

        let fileDescriptor = open(
            FluxusPaths.runLockURL.path,
            O_CREAT | O_RDWR,
            mode_t(S_IRUSR | S_IWUSR)
        )

        guard fileDescriptor >= 0 else {
            let errorCode = errno
            throw NSError(
                domain: "Fluxusctl",
                code: Int(errorCode),
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Failed to open cleanup lock file: \(posixMessage(errorCode))"
                ]
            )
        }

        defer { close(fileDescriptor) }

        if flock(fileDescriptor, LOCK_EX | LOCK_NB) != 0 {
            let errorCode = errno
            if errorCode == EWOULDBLOCK {
                return nil
            }

            throw NSError(
                domain: "Fluxusctl",
                code: Int(errorCode),
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Failed to acquire cleanup lock: \(posixMessage(errorCode))"
                ]
            )
        }

        defer { _ = flock(fileDescriptor, LOCK_UN) }

        return try operation()
    }

    private static func posixMessage(_ errorCode: Int32) -> String {
        guard let message = String(validatingUTF8: strerror(errorCode)) else {
            return "unknown error"
        }
        return message
    }
}

FluxusctlMain.run()
