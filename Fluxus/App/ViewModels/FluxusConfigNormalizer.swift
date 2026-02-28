import Foundation

enum FluxusConfigNormalizer {
    static func normalize(
        _ source: FluxusConfig,
        requireRoots: Bool,
        validatePaths: Bool
    ) throws -> FluxusConfig {
        var normalized = source

        let archiveBasePath = normalized.archive.basePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !archiveBasePath.isEmpty else {
            throw NSError(
                domain: "Fluxus",
                code: 15,
                userInfo: [NSLocalizedDescriptionKey: "Archive folder path is required."]
            )
        }

        normalized.archive.basePath = archiveBasePath
        let archiveBaseURL = canonicalizedURL(path: FluxusPaths.expandTilde(in: archiveBasePath))

        guard normalized.schedule.isValid else {
            throw NSError(
                domain: "Fluxus",
                code: 11,
                userInfo: [NSLocalizedDescriptionKey: "Schedule must be within 00:00 to 23:59."]
            )
        }

        if requireRoots && normalized.roots.isEmpty {
            throw NSError(
                domain: "Fluxus",
                code: 12,
                userInfo: [NSLocalizedDescriptionKey: "Add at least one folder target and retention before proceeding."]
            )
        }

        var usedNames: Set<String> = []
        for index in normalized.roots.indices {
            let trimmedPath = normalized.roots[index].path.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedName = normalized.roots[index].name.trimmingCharacters(in: .whitespacesAndNewlines)

            if validatePaths && trimmedPath.isEmpty {
                throw NSError(
                    domain: "Fluxus",
                    code: 13,
                    userInfo: [NSLocalizedDescriptionKey: "Folder path is required for target \(index + 1)."]
                )
            }

            if validatePaths && normalized.roots[index].retentionDays < 0 {
                throw NSError(
                    domain: "Fluxus",
                    code: 14,
                    userInfo: [NSLocalizedDescriptionKey: "Retention must be >= 0 for target \(index + 1)."]
                )
            }

            let baseName = fallbackName(
                explicitName: trimmedName,
                path: trimmedPath,
                index: index
            )
            let uniqueName = uniqueRootName(baseName: baseName, used: &usedNames)

            normalized.roots[index].name = uniqueName
            normalized.roots[index].path = trimmedPath
            if normalized.roots[index].action == .archive {
                let rootURL = canonicalizedURL(path: FluxusPaths.expandTilde(in: trimmedPath))
                let rootPrefix = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"

                if archiveBaseURL.path == rootURL.path || archiveBaseURL.path.hasPrefix(rootPrefix) {
                    throw NSError(
                        domain: "Fluxus",
                        code: 16,
                        userInfo: [NSLocalizedDescriptionKey: "Archive folder must not be inside archive target '\(uniqueName)'."]
                    )
                }
            }
        }

        return normalized
    }

    private static func fallbackName(explicitName: String, path: String, index: Int) -> String {
        if !explicitName.isEmpty {
            return explicitName
        }

        if !path.isEmpty {
            let lastComponent = URL(fileURLWithPath: FluxusPaths.expandTilde(in: path)).lastPathComponent
            if !lastComponent.isEmpty && lastComponent != "/" {
                return lastComponent
            }
        }

        return "root-\(index + 1)"
    }

    private static func uniqueRootName(baseName: String, used: inout Set<String>) -> String {
        let base = baseName.lowercased()
        if !used.contains(base) {
            used.insert(base)
            return baseName
        }

        var suffix = 2
        while true {
            let candidate = "\(baseName)-\(suffix)"
            let key = candidate.lowercased()
            if !used.contains(key) {
                used.insert(key)
                return candidate
            }
            suffix += 1
        }
    }

    private static func canonicalizedURL(path: String) -> URL {
        URL(fileURLWithPath: FluxusPaths.canonicalPath(for: path))
    }
}
