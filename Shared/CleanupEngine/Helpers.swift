import Foundation
import Darwin

extension CleanupEngine {
    func archiveRunDestination(now: Date, config: FluxusConfig) throws -> URL {
        let archiveBase = canonicalizedFileURL(forPath: config.archive.expandedBasePath)
        let monthDirectory = archiveBase
            .appendingPathComponent(archiveMonthComponent(for: now), isDirectory: true)

        try FluxusPaths.ensureDirectory(monthDirectory)
        return uniqueDestination(for: archiveRunOutputFileName(for: now), in: monthDirectory)
    }

    func uniqueDestination(for fileName: String, in directory: URL) -> URL {
        var destination = directory.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: destination.path) else {
            return destination
        }

        let sourceURL = URL(fileURLWithPath: fileName)
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension

        var index = 1
        while fileManager.fileExists(atPath: destination.path) {
            let suffix = " (\(index))"
            let candidateName: String
            if ext.isEmpty {
                candidateName = baseName + suffix
            } else {
                candidateName = baseName + suffix + "." + ext
            }
            destination = directory.appendingPathComponent(candidateName)
            index += 1
        }

        return destination
    }

    func archiveRunOutputFileName(for date: Date) -> String {
        "fluxus-archive-run-\(archiveRunTimestampComponent(for: date)).zip"
    }

    func canonicalizedFileURL(forPath path: String) -> URL {
        URL(fileURLWithPath: FluxusPaths.canonicalPath(for: path))
    }

    func canonicalizedFileURL(for url: URL) -> URL {
        canonicalizedFileURL(forPath: url.path)
    }

    func fileIdentity(at path: String) throws -> FileIdentity {
        var info = stat()
        if lstat(path, &info) != 0 {
            let code = errno
            let details = String(cString: strerror(code))
            throw NSError(
                domain: "Fluxus.CleanupEngine",
                code: 303,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to inspect '\(path)': \(details)"
                ]
            )
        }

        let type = info.st_mode & S_IFMT
        guard type == S_IFREG else {
            throw NSError(
                domain: "Fluxus.CleanupEngine",
                code: 303,
                userInfo: [
                    NSLocalizedDescriptionKey: "Refusing non-regular file at '\(path)'"
                ]
            )
        }

        return FileIdentity(
            device: UInt64(info.st_dev),
            inode: UInt64(info.st_ino)
        )
    }

    func ensureCandidateUnchangedAndWithinRoot(
        _ candidate: Candidate,
        rootPath: String,
        safePrefix: String
    ) throws {
        let currentIdentity = try fileIdentity(at: candidate.url.path)
        guard currentIdentity == candidate.identity else {
            throw NSError(
                domain: "Fluxus.CleanupEngine",
                code: 304,
                userInfo: [
                    NSLocalizedDescriptionKey: "Candidate changed after scan; skipping to avoid unsafe operation."
                ]
            )
        }

        let resolvedCandidatePath = canonicalizedFileURL(for: candidate.url).path
        guard isSafeCandidatePath(
            candidatePath: resolvedCandidatePath,
            rootPath: rootPath,
            safePrefix: safePrefix
        ) else {
            throw NSError(
                domain: "Fluxus.CleanupEngine",
                code: 304,
                userInfo: [
                    NSLocalizedDescriptionKey: "Candidate escaped configured root after symlink resolution."
                ]
            )
        }
    }

    func compressItemToZip(sourceURL: URL, destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = [
            "-c",
            "-k",
            "--sequesterRsrc",
            sourceURL.path,
            destinationURL.path
        ]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw NSError(
                domain: "Fluxus.CleanupEngine",
                code: 301,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to start ZIP compression for '\(sourceURL.path)': \(error.localizedDescription)"
                ]
            )
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let stdout = String(
                data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            let stderr = String(
                data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            let details = [stderr, stdout]
                .filter { !$0.isEmpty }
                .joined(separator: " | ")

            let message: String
            if details.isEmpty {
                message = "ZIP compression failed for '\(sourceURL.path)' with exit code \(process.terminationStatus)."
            } else {
                message = "ZIP compression failed for '\(sourceURL.path)' with exit code \(process.terminationStatus): \(details)"
            }

            throw NSError(
                domain: "Fluxus.CleanupEngine",
                code: 301,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }

    func pathPrefix(for rootPath: String) -> String {
        rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
    }

    func updateTopFolderStats(
        map: inout [String: (count: Int, bytes: Int64)],
        candidate: Candidate,
        rootPathPrefix: String
    ) {
        let fullPath = candidate.url.path
        let relativePath = String(fullPath.dropFirst(rootPathPrefix.count))
        let firstComponent = relativePath.split(separator: "/").first.map(String.init) ?? "(root)"
        let key = "\(candidate.root.name)/\(firstComponent)"

        let current = map[key] ?? (0, 0)
        map[key] = (current.count + 1, current.bytes + candidate.sizeBytes)
    }

    func topFolders(from map: [String: (count: Int, bytes: Int64)], limit: Int = 10) -> [TopFolderSummary] {
        map
            .map { key, value in
                TopFolderSummary(folder: key, count: value.count, bytes: value.bytes)
            }
            .sorted { lhs, rhs in
                if lhs.bytes == rhs.bytes {
                    if lhs.count == rhs.count {
                        return lhs.folder < rhs.folder
                    }
                    return lhs.count > rhs.count
                }
                return lhs.bytes > rhs.bytes
            }
            .prefix(limit)
            .map { $0 }
    }

    func isSafeCandidatePath(candidatePath: String, rootPath: String, safePrefix: String) -> Bool {
        candidatePath != rootPath && candidatePath.hasPrefix(safePrefix)
    }

    func orderedCandidatesForExecution(_ candidates: [Candidate]) -> [Candidate] {
        candidates.sorted { lhs, rhs in
            if lhs.modifiedDate == rhs.modifiedDate {
                return lhs.url.path < rhs.url.path
            }
            return lhs.modifiedDate < rhs.modifiedDate
        }
    }

    private func archiveMonthComponent(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    private func archiveRunTimestampComponent(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}
