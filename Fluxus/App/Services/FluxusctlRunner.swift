import Foundation

struct FluxusctlExecutionResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

enum FluxusctlRunnerError: LocalizedError {
    case helperNotFound
    case failedToRun(String)

    var errorDescription: String? {
        switch self {
        case .helperNotFound:
            return "Bundled Fluxusctl helper was not found in the app bundle."
        case .failedToRun(let message):
            return message
        }
    }
}

struct FluxusctlRunner {
    func helperURL() throws -> URL {
        if let auxiliary = Bundle.main.url(forAuxiliaryExecutable: "Fluxusctl") {
            return auxiliary
        }

        let fallback = Bundle.main.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent("Fluxusctl", isDirectory: false)

        if FileManager.default.isExecutableFile(atPath: fallback.path) {
            return fallback
        }

        throw FluxusctlRunnerError.helperNotFound
    }

    func run(arguments: [String]) throws -> FluxusctlExecutionResult {
        let process = Process()
        process.executableURL = try helperURL()
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw FluxusctlRunnerError.failedToRun("Failed to start Fluxusctl: \(error.localizedDescription)")
        }

        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return FluxusctlExecutionResult(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus)
    }
}
