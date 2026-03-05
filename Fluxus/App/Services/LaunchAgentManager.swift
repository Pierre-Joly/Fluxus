import Foundation
import Darwin

struct LaunchAgentManager {
    private var launchDomains: [String] {
        let uid = getuid()
        return ["gui/\(uid)", "user/\(uid)"]
    }

    func installOrUpdate(
        helperPath: String,
        configPath: String,
        schedule: ScheduleConfig,
        enabled: Bool
    ) throws -> String {
        if !enabled {
            _ = try uninstall()
            return "LaunchAgent disabled."
        }

        guard schedule.isValid else {
            throw NSError(
                domain: "Fluxus",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid schedule. Hour must be 0...23 and minute 0...59."]
            )
        }

        try FluxusPaths.ensureDirectory(FluxusPaths.launchAgentsDirectory)
        try FluxusPaths.ensureDirectory(FluxusPaths.logsDirectory)
        try FluxusPaths.ensureDirectory(FluxusPaths.appSupportDirectory)

        let plist = launchAgentDictionary(
            helperPath: helperPath,
            configPath: configPath,
            schedule: schedule,
            logPath: FluxusPaths.cleanupLogURL.path
        )

        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )

        try plistData.write(to: FluxusPaths.launchAgentPlistURL, options: .atomic)

        _ = try bootout(ignoreMissing: true)

        var failures: [LaunchctlResult] = []
        for domain in launchDomains {
            let result = try runLaunchctl(arguments: [
                "bootstrap",
                domain,
                FluxusPaths.launchAgentPlistURL.path
            ])

            if result.exitCode == 0 || looksAlreadyLoaded(normalizedMessage(result)) {
                return enabledMessage(for: schedule)
            }

            failures.append(result)
        }

        if failures.allSatisfy({ isSessionAccessIssue(normalizedMessage($0)) }) {
            let detail = briefMessage(from: failures.first)
            return "Configuration saved. LaunchAgent could not be activated in this session (\(detail)). It may activate after next login."
        }

        let details = failures
            .map { "[\($0.exitCode)] \(briefMessage(from: $0))" }
            .joined(separator: " | ")

        throw NSError(
            domain: "Fluxus",
            code: Int(failures.first?.exitCode ?? 1),
            userInfo: [NSLocalizedDescriptionKey: "launchctl bootstrap failed: \(details)"]
        )
    }

    func uninstall() throws -> String {
        _ = try bootout(ignoreMissing: true)

        if FileManager.default.fileExists(atPath: FluxusPaths.launchAgentPlistURL.path) {
            try FileManager.default.removeItem(at: FluxusPaths.launchAgentPlistURL)
        }

        return "LaunchAgent uninstalled (plist removed)."
    }

    func isLoaded() -> Bool {
        for domain in launchDomains {
            let result = try? runLaunchctl(arguments: [
                "print",
                "\(domain)/\(FluxusPaths.launchAgentLabel)"
            ])

            if result?.exitCode == 0 {
                return true
            }
        }

        return false
    }

    private func launchAgentDictionary(
        helperPath: String,
        configPath: String,
        schedule: ScheduleConfig,
        logPath: String
    ) -> [String: Any] {
        [
            "Label": FluxusPaths.launchAgentLabel,
            "ProgramArguments": [
                helperPath,
                "--run-if-missed",
                "--config",
                configPath
            ],
            "StartCalendarInterval": [
                "Hour": schedule.hour,
                "Minute": schedule.minute
            ],
            "StandardOutPath": logPath,
            "StandardErrorPath": logPath,
            "RunAtLoad": true
        ]
    }

    @discardableResult
    private func bootout(ignoreMissing: Bool) throws -> [LaunchctlResult] {
        var results: [LaunchctlResult] = []

        for domain in launchDomains {
            let result = try runLaunchctl(arguments: [
                "bootout",
                domain,
                FluxusPaths.launchAgentPlistURL.path
            ])
            results.append(result)

            guard result.exitCode != 0 else {
                continue
            }

            if !ignoreMissing {
                throw NSError(
                    domain: "Fluxus",
                    code: Int(result.exitCode),
                    userInfo: [NSLocalizedDescriptionKey: "launchctl bootout failed: \(briefMessage(from: result))"]
                )
            }

            let normalized = normalizedMessage(result)
            let looksIgnorable = normalized.contains("no such process")
                || normalized.contains("could not find service")
                || normalized.contains("service is disabled")
                || normalized.contains("not loaded")
                || isSessionAccessIssue(normalized)

            if !looksIgnorable {
                throw NSError(
                    domain: "Fluxus",
                    code: Int(result.exitCode),
                    userInfo: [NSLocalizedDescriptionKey: "launchctl bootout failed: \(briefMessage(from: result))"]
                )
            }
        }

        return results
    }

    private func enabledMessage(for schedule: ScheduleConfig) -> String {
        "LaunchAgent enabled at \(String(format: "%02d:%02d", schedule.hour, schedule.minute))."
    }

    private func normalizedMessage(_ result: LaunchctlResult) -> String {
        (result.stderr + "\n" + result.stdout).lowercased()
    }

    private func briefMessage(from result: LaunchctlResult?) -> String {
        guard let result else {
            return "unknown launchctl error"
        }

        let message = [result.stderr, result.stdout]
            .filter { !$0.isEmpty }
            .joined(separator: " | ")

        if message.isEmpty {
            return "exit code \(result.exitCode)"
        }

        return message
    }

    private func looksAlreadyLoaded(_ normalized: String) -> Bool {
        normalized.contains("already loaded") || normalized.contains("service already loaded")
    }

    private func isSessionAccessIssue(_ normalized: String) -> Bool {
        normalized.contains("input/output error")
            || normalized.contains("bad request")
            || normalized.contains("operation not permitted")
            || normalized.contains("not privileged")
            || normalized.contains("could not find domain")
            || normalized.contains("domain does not support specified action")
    }

    private func runLaunchctl(arguments: [String]) throws -> LaunchctlResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return LaunchctlResult(
            exitCode: process.terminationStatus,
            stdout: String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            stderr: String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )
    }
}

private struct LaunchctlResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}
