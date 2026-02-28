import Foundation

extension CleanupEngine {
    func validate(config: FluxusConfig) -> ValidateOutput {
        let issues = validationIssues(for: config)

        return ValidateOutput(
            command: "validate",
            checkedAt: FluxusJSON.isoString(nowProvider()),
            valid: issues.isEmpty,
            issues: issues
        )
    }

    func validationIssues(for config: FluxusConfig) -> [String] {
        var issues: [String] = []

        if !config.schedule.isValid {
            issues.append("Schedule must be within hour 0...23 and minute 0...59")
        }

        if config.archive.basePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Archive base path must not be empty")
        }

        if config.roots.isEmpty {
            issues.append("At least one root must be configured")
        }

        for root in config.roots {
            appendRootValidationIssues(for: root, to: &issues)
        }

        let archiveBasePath = canonicalizedFileURL(forPath: FluxusPaths.expandTilde(in: config.archive.basePath)).path
        for root in config.roots where root.action == .archive {
            let rootPath = canonicalizedFileURL(forPath: root.expandedPath).path
            let rootPrefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
            if archiveBasePath == rootPath || archiveBasePath.hasPrefix(rootPrefix) {
                issues.append("Archive base path must not be inside archive root '\(root.name)'")
            }
        }

        return issues
    }

    private func appendRootValidationIssues(for root: RootRuleConfig, to issues: inout [String]) {
        if root.retentionDays < 0 {
            issues.append("Root '\(root.name)' has invalid retentionDays: \(root.retentionDays)")
        }

        let expandedPath = root.expandedPath
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory) {
            issues.append("Root '\(root.name)' does not exist: \(expandedPath)")
            return
        }

        if !isDirectory.boolValue {
            issues.append("Root '\(root.name)' is not a directory: \(expandedPath)")
        }
    }
}
