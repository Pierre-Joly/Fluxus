import Foundation

extension CleanupEngine {
    func collectCandidates(config: FluxusConfig, now: Date) -> ScanResult {
        var result = ScanResult()
        result.issues = validationIssues(for: config)

        for (rootIndex, root) in config.roots.enumerated() {
            let rootResult = scanRoot(root, rootIndex: rootIndex, now: now)
            result.candidates.append(contentsOf: rootResult.candidates)
            result.roots.append(rootResult.summary)
        }

        return result
    }

    private func scanRoot(_ root: RootRuleConfig, rootIndex: Int, now: Date) -> RootScanResult {
        let rootURL = canonicalizedFileURL(forPath: root.expandedPath)
        let rootPrefix = pathPrefix(for: rootURL.path)

        var summary = RootExecutionSummary(
            name: root.name,
            path: rootURL.path,
            retentionDays: root.retentionDays,
            action: root.action,
            candidateCount: 0,
            processedCount: 0,
            bytes: 0,
            errors: []
        )

        guard isAvailableDirectory(rootURL) else {
            summary.errors.append("Root directory unavailable")
            return RootScanResult(summary: summary, candidates: [])
        }

        guard root.retentionDays >= 0 else {
            summary.errors.append("Retention days must be >= 0")
            return RootScanResult(summary: summary, candidates: [])
        }

        var candidates: [Candidate] = []
        let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: Array(scanResourceKeys),
            options: [],
            errorHandler: { url, error in
                let message = "Enumeration failed at \(url.path): \(error.localizedDescription)"
                summary.errors.append(message)
                self.logger("[EnumerateError] \(message)")
                return true
            }
        )

        while let item = enumerator?.nextObject() as? URL {
            inspectEnumeratedItem(
                item,
                enumerator: enumerator,
                root: root,
                rootIndex: rootIndex,
                rootPrefix: rootPrefix,
                now: now,
                summary: &summary,
                candidates: &candidates
            )
        }

        return RootScanResult(summary: summary, candidates: candidates)
    }

    private func isAvailableDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return false
        }
        return isDirectory.boolValue
    }

    private func inspectEnumeratedItem(
        _ item: URL,
        enumerator: FileManager.DirectoryEnumerator?,
        root: RootRuleConfig,
        rootIndex: Int,
        rootPrefix: String,
        now: Date,
        summary: inout RootExecutionSummary,
        candidates: inout [Candidate]
    ) {
        let standardizedItem = item.standardizedFileURL
        let itemPath = standardizedItem.path

        guard itemPath.hasPrefix(rootPrefix) else {
            summary.errors.append("Skipped item outside root: \(itemPath)")
            return
        }

        do {
            if let candidate = try candidateIfEligible(
                itemURL: standardizedItem,
                enumerator: enumerator,
                root: root,
                rootIndex: rootIndex,
                now: now
            ) {
                candidates.append(candidate)
                summary.candidateCount += 1
                summary.bytes += candidate.sizeBytes
            }
        } catch {
            let message = "Failed to inspect \(itemPath): \(error.localizedDescription)"
            summary.errors.append(message)
            logger("[InspectError] \(message)")
        }
    }

    private func candidateIfEligible(
        itemURL: URL,
        enumerator: FileManager.DirectoryEnumerator?,
        root: RootRuleConfig,
        rootIndex: Int,
        now: Date
    ) throws -> Candidate? {
        let values = try itemURL.resourceValues(forKeys: scanResourceKeys)

        if values.isSymbolicLink == true {
            skipDescendantsIfDirectory(values.isDirectory == true, enumerator: enumerator)
            return nil
        }

        if values.isPackage == true, values.isDirectory == true {
            enumerator?.skipDescendants()
            return nil
        }

        guard values.isRegularFile == true else {
            return nil
        }

        guard let relevantDate = values.contentModificationDate ?? values.creationDate else {
            throw NSError(
                domain: "Fluxus.CleanupEngine",
                code: 101,
                userInfo: [NSLocalizedDescriptionKey: "Missing modification/creation date"]
            )
        }

        let requiredAge = TimeInterval(root.retentionDays) * 24 * 60 * 60
        guard now.timeIntervalSince(relevantDate) >= requiredAge else {
            return nil
        }

        let sizeBytes = Int64(values.fileSize ?? 0)
        let identity = try fileIdentity(at: itemURL.path)
        return Candidate(
            rootIndex: rootIndex,
            root: root,
            url: itemURL,
            modifiedDate: relevantDate,
            sizeBytes: sizeBytes,
            identity: identity
        )
    }

    private func skipDescendantsIfDirectory(
        _ isDirectory: Bool,
        enumerator: FileManager.DirectoryEnumerator?
    ) {
        if isDirectory {
            enumerator?.skipDescendants()
        }
    }

    private var scanResourceKeys: Set<URLResourceKey> {
        [
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .isPackageKey,
            .contentModificationDateKey,
            .creationDateKey,
            .fileSizeKey
        ]
    }
}
