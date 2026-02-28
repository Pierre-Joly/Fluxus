import Foundation

enum FluxusPaths {
    static let launchAgentLabel = "com.pierre.Fluxus"

    static var homeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    static var appSupportDirectory: URL {
        homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("Fluxus", isDirectory: true)
    }

    static var configURL: URL {
        appSupportDirectory.appendingPathComponent("config.json")
    }

    static var lastRunURL: URL {
        appSupportDirectory.appendingPathComponent("last_run.json")
    }

    static var logsDirectory: URL {
        homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("Fluxus", isDirectory: true)
    }

    static var cleanupLogURL: URL {
        logsDirectory.appendingPathComponent("cleanup.log")
    }

    static var launchAgentsDirectory: URL {
        homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
    }

    static var launchAgentPlistURL: URL {
        launchAgentsDirectory.appendingPathComponent("\(launchAgentLabel).plist")
    }

    static var archiveBaseDirectory: URL {
        homeDirectory
            .appendingPathComponent("Archive", isDirectory: true)
            .appendingPathComponent("Quarantine", isDirectory: true)
    }

    static func expandTilde(in path: String) -> String {
        if path == "~" {
            return homeDirectory.path
        }
        if path.hasPrefix("~/") {
            let suffix = String(path.dropFirst(2))
            return homeDirectory.appendingPathComponent(suffix).path
        }
        return (path as NSString).expandingTildeInPath
    }

    static func ensureDirectory(_ directoryURL: URL) throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    static func ensureParentDirectory(for fileURL: URL) throws {
        try ensureDirectory(fileURL.deletingLastPathComponent())
    }

    static func canonicalPath(for path: String) -> String {
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        let fileManager = FileManager.default

        var existingPath = standardizedPath
        var missingComponents: [String] = []
        while existingPath != "/" && !fileManager.fileExists(atPath: existingPath) {
            let component = URL(fileURLWithPath: existingPath).lastPathComponent
            missingComponents.append(component)
            existingPath = URL(fileURLWithPath: existingPath).deletingLastPathComponent().path
        }

        var resolvedURL = URL(fileURLWithPath: existingPath)
            .resolvingSymlinksInPath()
            .standardizedFileURL

        for component in missingComponents.reversed() {
            resolvedURL.appendPathComponent(component, isDirectory: false)
        }

        return resolvedURL.standardizedFileURL.path
    }
}
