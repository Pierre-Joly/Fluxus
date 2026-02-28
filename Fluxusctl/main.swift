import Foundation

enum CLICommand {
    case simulation
    case run
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
                let output = engine.run(config: config)
                do {
                    try ConfigStore.saveLastRun(output)
                } catch {
                    fputs("Fluxusctl warning: Failed to write last_run.json: \(error.localizedDescription)\n", stderr)
                }
                try writeJSON(output)
                exit(output.errorCount == 0 ? EXIT_SUCCESS : EXIT_FAILURE)
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

    private static func parse(arguments: [String]) throws -> CLIOptions {
        if arguments.contains("--help") || arguments.isEmpty {
            throw CLIError.invalidArguments(usage)
        }

        // Keep --dry-run as a backward-compatible alias while preferring --simulate.
        let hasSimulation = arguments.contains("--simulate") || arguments.contains("--dry-run")
        let hasRun = arguments.contains("--run")
        let hasValidate = arguments.contains("--validate")

        let modeCount = [hasSimulation, hasRun, hasValidate].filter { $0 }.count
        guard modeCount == 1 else {
            throw CLIError.invalidArguments("Specify exactly one of --simulate, --run, --validate\n\n\(usage)")
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
    """
}

FluxusctlMain.run()
