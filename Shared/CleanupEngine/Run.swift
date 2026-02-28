import Foundation

extension CleanupEngine {
    private struct ArchivePreparation {
        let candidate: Candidate
        let rootPath: String
        let safePrefix: String
        let stagingRelativePath: String
    }

    func run(config: FluxusConfig) -> RunOutput {
        let startedAt = nowProvider()
        let scan = collectCandidates(config: config, now: startedAt)
        if !scan.issues.isEmpty {
            for issue in scan.issues {
                logger("[Validation] \(issue)")
            }
            let finishedAt = nowProvider()
            return validationFailureOutput(
                for: scan,
                startedAt: startedAt,
                finishedAt: finishedAt
            )
        }

        let orderedCandidates = orderedCandidatesForExecution(scan.candidates)
        let trashCandidates = orderedCandidates.filter { $0.root.action == .trash }
        let archiveCandidates = orderedCandidates.filter { $0.root.action == .archive }

        var stats = RunAccumulator(roots: scan.roots)

        for candidate in trashCandidates {
            processTrashCandidate(candidate, stats: &stats)
        }
        processArchiveCandidatesBatch(
            archiveCandidates,
            runStartedAt: startedAt,
            config: config,
            stats: &stats
        )

        let prunedDirectoryCount = pruneEmptyDirectories(afterRunFor: config, stats: &stats)

        let finishedAt = nowProvider()

        return RunOutput(
            command: "run",
            startedAt: FluxusJSON.isoString(startedAt),
            finishedAt: FluxusJSON.isoString(finishedAt),
            candidateCount: orderedCandidates.count,
            processedCount: stats.processedCount,
            trashedCount: stats.trashedCount,
            archivedCount: stats.archivedCount,
            skippedCount: stats.skippedCount,
            errorCount: stats.errorCount,
            prunedDirectoryCount: prunedDirectoryCount,
            totalBytes: stats.totalBytes,
            roots: stats.roots,
            topFolders: topFolders(from: stats.topFoldersMap),
            errors: stats.errors
        )
    }

    private func processTrashCandidate(_ candidate: Candidate, stats: inout RunAccumulator) {
        let rootURL = canonicalizedFileURL(forPath: candidate.root.expandedPath)
        let safePrefix = pathPrefix(for: rootURL.path)
        let candidatePath = candidate.url.path

        do {
            try ensureCandidateUnchangedAndWithinRoot(
                candidate,
                rootPath: rootURL.path,
                safePrefix: safePrefix
            )
        } catch {
            stats.recordSafetySkip(
                candidatePath: candidatePath,
                message: error.localizedDescription,
                rootIndex: candidate.rootIndex,
                logger: logger
            )
            return
        }

        do {
            try applyTrashAction(for: candidate)
            stats.recordSuccess(for: candidate)
            updateTopFolderStats(
                map: &stats.topFoldersMap,
                candidate: candidate,
                rootPathPrefix: safePrefix
            )
        } catch {
            stats.recordFailure(
                candidatePath: candidatePath,
                message: error.localizedDescription,
                rootIndex: candidate.rootIndex,
                logger: logger
            )
        }
    }

    private func applyTrashAction(for candidate: Candidate) throws {
        _ = try fileManager.trashItem(at: candidate.url, resultingItemURL: nil)
    }

    private func processArchiveCandidatesBatch(
        _ candidates: [Candidate],
        runStartedAt: Date,
        config: FluxusConfig,
        stats: inout RunAccumulator
    ) {
        guard !candidates.isEmpty else {
            return
        }

        var prepared: [ArchivePreparation] = []
        prepared.reserveCapacity(candidates.count)

        for candidate in candidates {
            let rootURL = canonicalizedFileURL(forPath: candidate.root.expandedPath)
            let rootPath = rootURL.path
            let safePrefix = pathPrefix(for: rootPath)
            let candidatePath = candidate.url.path

            do {
                try ensureCandidateUnchangedAndWithinRoot(
                    candidate,
                    rootPath: rootPath,
                    safePrefix: safePrefix
                )
                prepared.append(
                    ArchivePreparation(
                        candidate: candidate,
                        rootPath: rootPath,
                        safePrefix: safePrefix,
                        stagingRelativePath: archiveStagingRelativePath(
                            for: candidate,
                            safePrefix: safePrefix
                        )
                    )
                )
            } catch {
                stats.recordSafetySkip(
                    candidatePath: candidatePath,
                    message: error.localizedDescription,
                    rootIndex: candidate.rootIndex,
                    logger: logger
                )
            }
        }

        guard !prepared.isEmpty else {
            return
        }

        let stagingDirectory: URL
        do {
            stagingDirectory = try createArchiveStagingDirectory()
        } catch {
            for item in prepared {
                stats.recordFailure(
                    candidatePath: item.candidate.url.path,
                    message: "Failed to prepare archive staging directory: \(error.localizedDescription)",
                    rootIndex: item.candidate.rootIndex,
                    logger: logger
                )
            }
            return
        }
        defer {
            try? fileManager.removeItem(at: stagingDirectory)
        }

        var staged: [ArchivePreparation] = []
        staged.reserveCapacity(prepared.count)
        for item in prepared {
            do {
                try stageArchiveCandidate(item, in: stagingDirectory)
                staged.append(item)
            } catch {
                stats.recordFailure(
                    candidatePath: item.candidate.url.path,
                    message: "Failed to stage candidate for archive: \(error.localizedDescription)",
                    rootIndex: item.candidate.rootIndex,
                    logger: logger
                )
            }
        }

        guard !staged.isEmpty else {
            return
        }

        let destinationURL: URL
        do {
            destinationURL = try archiveRunDestination(now: runStartedAt, config: config)
        } catch {
            for item in staged {
                stats.recordFailure(
                    candidatePath: item.candidate.url.path,
                    message: "Failed to resolve archive destination: \(error.localizedDescription)",
                    rootIndex: item.candidate.rootIndex,
                    logger: logger
                )
            }
            return
        }

        do {
            try compressItemToZip(sourceURL: stagingDirectory, destinationURL: destinationURL)
        } catch {
            let errorMessage = "Failed to create combined archive bundle: \(error.localizedDescription)"
            for item in staged {
                stats.recordFailure(
                    candidatePath: item.candidate.url.path,
                    message: errorMessage,
                    rootIndex: item.candidate.rootIndex,
                    logger: logger
                )
            }
            return
        }

        var archivedCountInBundle = 0
        for item in staged {
            let candidate = item.candidate

            do {
                try ensureCandidateUnchangedAndWithinRoot(
                    candidate,
                    rootPath: item.rootPath,
                    safePrefix: item.safePrefix
                )
            } catch {
                stats.recordSafetySkip(
                    candidatePath: candidate.url.path,
                    message: "Archive bundle created but source changed before removal: \(error.localizedDescription)",
                    rootIndex: candidate.rootIndex,
                    logger: logger
                )
                continue
            }

            do {
                try fileManager.removeItem(at: candidate.url)
                stats.recordSuccess(for: candidate)
                updateTopFolderStats(
                    map: &stats.topFoldersMap,
                    candidate: candidate,
                    rootPathPrefix: item.safePrefix
                )
                archivedCountInBundle += 1
            } catch {
                stats.recordFailure(
                    candidatePath: candidate.url.path,
                    message: "Archive bundle created but failed to remove source: \(error.localizedDescription)",
                    rootIndex: candidate.rootIndex,
                    logger: logger
                )
            }
        }

        if archivedCountInBundle == 0 {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try? fileManager.removeItem(at: destinationURL)
            }
            return
        }

        logger("[Archive] Created archive bundle \(destinationURL.path) with \(archivedCountInBundle) file(s).")
    }

    private func stageArchiveCandidate(_ item: ArchivePreparation, in stagingDirectory: URL) throws {
        let stagedFileURL = stagingDirectory.appendingPathComponent(item.stagingRelativePath)
        let parentDirectory = stagedFileURL.deletingLastPathComponent()
        try FluxusPaths.ensureDirectory(parentDirectory)
        try fileManager.copyItem(at: item.candidate.url, to: stagedFileURL)
    }

    private func archiveStagingRelativePath(for candidate: Candidate, safePrefix: String) -> String {
        let relativePath = String(candidate.url.path.dropFirst(safePrefix.count))
        let rootComponent = sanitizedArchiveComponent(rootComponentName(for: candidate))
        return "root-\(candidate.rootIndex)-\(rootComponent)/\(relativePath)"
    }

    private func rootComponentName(for candidate: Candidate) -> String {
        let explicitName = candidate.root.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicitName.isEmpty {
            return explicitName
        }

        let fallback = URL(fileURLWithPath: candidate.root.expandedPath).lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback.isEmpty ? "target" : fallback
    }

    private func sanitizedArchiveComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let normalized = value.unicodeScalars.map { scalar -> String in
            allowed.contains(scalar) ? String(scalar) : "-"
        }.joined()
        let collapsed = normalized.replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
        let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return trimmed.isEmpty ? "target" : trimmed
    }

    private func createArchiveStagingDirectory() throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("Fluxus-archive-stage-\(UUID().uuidString)", isDirectory: true)
        try FluxusPaths.ensureDirectory(directory)
        return directory
    }

    private func pruneEmptyDirectories(afterRunFor config: FluxusConfig, stats: inout RunAccumulator) -> Int {
        var totalPruned = 0

        for (rootIndex, root) in config.roots.enumerated() {
            totalPruned += pruneEmptyDirectories(for: root, rootIndex: rootIndex, stats: &stats)
        }

        return totalPruned
    }

    private func pruneEmptyDirectories(for root: RootRuleConfig, rootIndex: Int, stats: inout RunAccumulator) -> Int {
        let rootURL = canonicalizedFileURL(forPath: root.expandedPath)
        let rootPath = rootURL.path
        let safePrefix = pathPrefix(for: rootPath)

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: rootPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            return 0
        }

        var directories: [URL] = []
        var enumerationErrors: [OperationError] = []
        let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey],
            options: [],
            errorHandler: { url, error in
                let message = "Directory prune enumeration failed at \(url.path): \(error.localizedDescription)"
                enumerationErrors.append(OperationError(path: url.path, message: message))
                self.logger("[PruneEnumerateError] \(message)")
                return true
            }
        )

        while let item = enumerator?.nextObject() as? URL {
            let standardized = item.standardizedFileURL
            let itemPath = standardized.path
            if itemPath == rootPath || !itemPath.hasPrefix(safePrefix) {
                continue
            }

            do {
                let values = try standardized.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey])
                if values.isSymbolicLink == true {
                    if values.isDirectory == true {
                        enumerator?.skipDescendants()
                    }
                    continue
                }
                guard values.isDirectory == true else {
                    continue
                }

                if values.isPackage == true {
                    enumerator?.skipDescendants()
                    continue
                }

                directories.append(standardized)
            } catch {
                let message = "Failed to inspect directory for prune \(itemPath): \(error.localizedDescription)"
                stats.roots[rootIndex].errors.append(message)
                stats.errorCount += 1
                stats.errors.append(OperationError(path: itemPath, message: message))
                logger("[PruneInspectError] \(message)")
            }
        }

        if !enumerationErrors.isEmpty {
            stats.errorCount += enumerationErrors.count
            stats.errors.append(contentsOf: enumerationErrors)
            for error in enumerationErrors {
                stats.roots[rootIndex].errors.append(error.message)
            }
        }

        directories.sort { lhs, rhs in
            let lhsDepth = lhs.pathComponents.count
            let rhsDepth = rhs.pathComponents.count
            if lhsDepth == rhsDepth {
                return lhs.path > rhs.path
            }
            return lhsDepth > rhsDepth
        }

        var prunedCount = 0
        for directory in directories {
            let path = directory.path
            guard path != rootPath, path.hasPrefix(safePrefix) else {
                continue
            }

            do {
                let content = try fileManager.contentsOfDirectory(atPath: path)
                guard content.isEmpty else {
                    continue
                }
                try fileManager.removeItem(at: directory)
                prunedCount += 1
                logger("[Prune] Removed empty directory: \(path)")
            } catch {
                let message = "Failed to prune empty directory \(path): \(error.localizedDescription)"
                stats.roots[rootIndex].errors.append(message)
                stats.errorCount += 1
                stats.errors.append(OperationError(path: path, message: message))
                logger("[PruneError] \(message)")
            }
        }

        return prunedCount
    }

    private func validationFailureOutput(
        for scan: ScanResult,
        startedAt: Date,
        finishedAt: Date
    ) -> RunOutput {
        let configErrors = scan.issues.map { issue in
            OperationError(path: "(config)", message: issue)
        }

        return RunOutput(
            command: "run",
            startedAt: FluxusJSON.isoString(startedAt),
            finishedAt: FluxusJSON.isoString(finishedAt),
            candidateCount: scan.candidates.count,
            processedCount: 0,
            trashedCount: 0,
            archivedCount: 0,
            skippedCount: scan.candidates.count,
            errorCount: configErrors.count,
            prunedDirectoryCount: 0,
            totalBytes: 0,
            roots: scan.roots,
            topFolders: [],
            errors: configErrors
        )
    }
}

private extension CleanupEngine.RunAccumulator {
    mutating func recordSafetySkip(
        candidatePath: String,
        message: String,
        rootIndex: Int,
        logger: (String) -> Void
    ) {
        skippedCount += 1
        errorCount += 1
        errors.append(OperationError(path: candidatePath, message: message))
        roots[rootIndex].errors.append(message)
        logger("[Safety] \(candidatePath): \(message)")
    }

    mutating func recordSuccess(for candidate: CleanupEngine.Candidate) {
        processedCount += 1
        totalBytes += candidate.sizeBytes
        roots[candidate.rootIndex].processedCount += 1
        roots[candidate.rootIndex].bytes += candidate.sizeBytes

        switch candidate.root.action {
        case .trash:
            trashedCount += 1
        case .archive:
            archivedCount += 1
        }
    }

    mutating func recordFailure(
        candidatePath: String,
        message: String,
        rootIndex: Int,
        logger: (String) -> Void
    ) {
        errorCount += 1
        errors.append(OperationError(path: candidatePath, message: message))
        roots[rootIndex].errors.append(message)
        logger("[RunError] \(candidatePath): \(message)")
    }
}
