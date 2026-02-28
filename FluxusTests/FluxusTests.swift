import Foundation
import XCTest
@testable import Fluxus

final class FluxusTests: XCTestCase {
    private var tempDirectories: [URL] = []

    override func tearDownWithError() throws {
        for directory in tempDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        tempDirectories.removeAll()
        try super.tearDownWithError()
    }

    @MainActor
    func testClearStatusRemovesMessageAndErrorState() {
        let viewModel = FluxusViewModel()
        viewModel.setStatus("Test message", isError: true)

        viewModel.clearStatus()

        XCTAssertEqual(viewModel.statusMessage, "")
        XCTAssertFalse(viewModel.statusIsError)
    }

    func testDefaultConfigStartsWithoutPrefilledRoots() {
        let config = FluxusConfig.default()

        XCTAssertFalse(config.enabled)
        XCTAssertTrue(config.roots.isEmpty)
        XCTAssertFalse(config.canSchedule)
        XCTAssertTrue(config.schedule.isValid)
        XCTAssertEqual(config.archive.basePath, "~/Archive/Quarantine")
    }

    func testCanScheduleRequiresEnabledAndTargets() {
        let root = RootRuleConfig(
            name: "target",
            path: "/tmp",
            retentionDays: 7,
            action: .trash,
            exclusions: .default
        )

        XCTAssertFalse(
            FluxusConfig(
                enabled: true,
                schedule: ScheduleConfig(hour: 1, minute: 0),
                roots: []
            ).canSchedule
        )
        XCTAssertFalse(
            FluxusConfig(
                enabled: false,
                schedule: ScheduleConfig(hour: 1, minute: 0),
                roots: [root]
            ).canSchedule
        )
        XCTAssertTrue(
            FluxusConfig(
                enabled: true,
                schedule: ScheduleConfig(hour: 1, minute: 0),
                roots: [root]
            ).canSchedule
        )
    }

    func testValidateFailsWithEmptyRoots() {
        let config = FluxusConfig(
            enabled: false,
            schedule: ScheduleConfig(hour: 3, minute: 15),
            roots: []
        )

        let output = CleanupEngine().validate(config: config)
        XCTAssertFalse(output.valid)
        XCTAssertTrue(output.issues.contains(where: { $0.contains("At least one root") }))
    }

    func testValidateFailsWithNegativeRetention() throws {
        let rootURL = try makeTemporaryDirectory(named: "fluxus-validate")
        let config = FluxusConfig(
            enabled: false,
            schedule: ScheduleConfig(hour: 4, minute: 20),
            roots: [
                RootRuleConfig(
                    name: "target",
                    path: rootURL.path,
                    retentionDays: -1,
                    action: .trash,
                    exclusions: .default
                )
            ]
        )

        let output = CleanupEngine().validate(config: config)
        XCTAssertFalse(output.valid)
        XCTAssertTrue(output.issues.contains(where: { $0.contains("invalid retentionDays") }))
    }

    func testSimulationIgnoresExclusionFieldsAndSkipsSymlinkEntries() throws {
        let rootURL = try makeTemporaryDirectory(named: "fluxus-dryrun")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let oldDate = now.addingTimeInterval(-40 * 24 * 60 * 60)

        let oldEligibleFile = rootURL.appendingPathComponent("old.txt")
        let newFile = rootURL.appendingPathComponent("new.txt")
        let keepDirectory = rootURL.appendingPathComponent("keep", isDirectory: true)
        let keepFile = keepDirectory.appendingPathComponent("ignored.txt")
        let gitDirectory = rootURL.appendingPathComponent(".git", isDirectory: true)
        let gitFile = gitDirectory.appendingPathComponent("ignored.txt")
        let symlinkFile = rootURL.appendingPathComponent("link-to-old.txt")

        try FileManager.default.createDirectory(at: keepDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: gitDirectory, withIntermediateDirectories: true)

        try Data("old".utf8).write(to: oldEligibleFile)
        try Data("new".utf8).write(to: newFile)
        try Data("keep".utf8).write(to: keepFile)
        try Data("git".utf8).write(to: gitFile)
        try FileManager.default.createSymbolicLink(atPath: symlinkFile.path, withDestinationPath: oldEligibleFile.path)

        try setModificationDate(oldDate, for: oldEligibleFile, keepFile, gitFile)
        try setModificationDate(now, for: newFile)

        let config = FluxusConfig(
            enabled: false,
            schedule: ScheduleConfig(hour: 1, minute: 0),
            roots: [
                RootRuleConfig(
                    name: "target",
                    path: rootURL.path,
                    retentionDays: 30,
                    action: .trash,
                    exclusions: ExclusionsConfig(
                        folderNames: ["keep"],
                        pathContains: [".git"]
                    )
                )
            ]
        )

        let output = CleanupEngine(nowProvider: { now }).simulation(config: config)
        let candidatePaths = Set(output.candidates.map(\.path))
        XCTAssertEqual(output.candidateCount, 3)
        XCTAssertEqual(candidatePaths, Set([oldEligibleFile.path, keepFile.path, gitFile.path]))
    }

    func testLegacyRootWithoutExclusionsDecodesWithDefaultExclusions() throws {
        let raw = """
        {
          "name": "downloads",
          "path": "~/Downloads",
          "retentionDays": 30,
          "action": "trash"
        }
        """

        let decoded = try FluxusJSON.decoder.decode(RootRuleConfig.self, from: Data(raw.utf8))
        XCTAssertEqual(decoded.exclusions, .default)
    }

    func testLegacyConfigWithoutArchiveDecodesWithDefaultArchiveSettings() throws {
        let raw = """
        {
          "enabled": false,
          "schedule": { "hour": 2, "minute": 30 },
          "roots": []
        }
        """

        let decoded = try FluxusJSON.decoder.decode(FluxusConfig.self, from: Data(raw.utf8))
        XCTAssertEqual(decoded.archive.basePath, "~/Archive/Quarantine")
    }

    func testRunPrunesEmptyDirectoriesAfterArchiving() throws {
        let rootURL = try makeTemporaryDirectory(named: "fluxus-prune-root")
        let archiveURL = try makeTemporaryDirectory(named: "fluxus-prune-archive")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let oldDate = now.addingTimeInterval(-3 * 24 * 60 * 60)

        let nestedDirectory = rootURL
            .appendingPathComponent("a", isDirectory: true)
            .appendingPathComponent("b", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)

        let oldFile = nestedDirectory.appendingPathComponent("old.txt")
        try Data("old".utf8).write(to: oldFile)
        try setModificationDate(oldDate, for: oldFile)

        let config = FluxusConfig(
            enabled: false,
            schedule: ScheduleConfig(hour: 1, minute: 0),
            roots: [
                RootRuleConfig(
                    name: "target",
                    path: rootURL.path,
                    retentionDays: 1,
                    action: .archive,
                    exclusions: .default
                )
            ],
            archive: ArchiveConfig(basePath: archiveURL.path)
        )

        let output = CleanupEngine(nowProvider: { now }).run(config: config)

        XCTAssertEqual(output.archivedCount, 1)
        XCTAssertGreaterThanOrEqual(output.prunedDirectoryCount, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: nestedDirectory.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldFile.path))

        let archivedFiles = try recursiveFiles(in: archiveURL)
        XCTAssertEqual(archivedFiles.count, 1)
        guard let archivedFile = archivedFiles.first else {
            XCTFail("Expected archived ZIP file")
            return
        }

        XCTAssertTrue(archivedFile.lastPathComponent.hasPrefix("fluxus-archive-run-"))
        XCTAssertTrue(archivedFile.lastPathComponent.hasSuffix(".zip"))
        let headerBytes = try zipMagicHeader(at: archivedFile)
        XCTAssertEqual(headerBytes, [0x50, 0x4B, 0x03, 0x04])
    }

    func testRunArchivesAllEligibleFilesIntoSingleBundlePerRun() throws {
        let firstRoot = try makeTemporaryDirectory(named: "fluxus-bundle-first-root")
        let secondRoot = try makeTemporaryDirectory(named: "fluxus-bundle-second-root")
        let archiveURL = try makeTemporaryDirectory(named: "fluxus-bundle-archive")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let oldDate = now.addingTimeInterval(-10 * 24 * 60 * 60)

        let firstFile = firstRoot.appendingPathComponent("folderA/old.txt")
        let secondFile = secondRoot.appendingPathComponent("folderB/old.txt")
        try FileManager.default.createDirectory(at: firstFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("first".utf8).write(to: firstFile)
        try Data("second".utf8).write(to: secondFile)
        try setModificationDate(oldDate, for: firstFile, secondFile)

        let config = FluxusConfig(
            enabled: false,
            schedule: ScheduleConfig(hour: 1, minute: 0),
            roots: [
                RootRuleConfig(
                    name: "first",
                    path: firstRoot.path,
                    retentionDays: 1,
                    action: .archive,
                    exclusions: .default
                ),
                RootRuleConfig(
                    name: "second",
                    path: secondRoot.path,
                    retentionDays: 1,
                    action: .archive,
                    exclusions: .default
                )
            ],
            archive: ArchiveConfig(basePath: archiveURL.path)
        )

        let output = CleanupEngine(nowProvider: { now }).run(config: config)

        XCTAssertEqual(output.archivedCount, 2)
        XCTAssertEqual(output.processedCount, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: firstFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: secondFile.path))

        let archivedFiles = try recursiveFiles(in: archiveURL)
        XCTAssertEqual(archivedFiles.count, 1)
        guard let archivedFile = archivedFiles.first else {
            XCTFail("Expected a single run archive bundle")
            return
        }

        XCTAssertTrue(archivedFile.lastPathComponent.hasPrefix("fluxus-archive-run-"))
        XCTAssertTrue(archivedFile.lastPathComponent.hasSuffix(".zip"))
        let headerBytes = try zipMagicHeader(at: archivedFile)
        XCTAssertEqual(headerBytes, [0x50, 0x4B, 0x03, 0x04])
    }

    func testValidateFailsWhenArchiveBaseIsInsideArchiveRoot() throws {
        let rootURL = try makeTemporaryDirectory(named: "fluxus-archive-root")
        let nestedArchive = rootURL.appendingPathComponent("Archive", isDirectory: true)

        let config = FluxusConfig(
            enabled: false,
            schedule: ScheduleConfig(hour: 1, minute: 0),
            roots: [
                RootRuleConfig(
                    name: "target",
                    path: rootURL.path,
                    retentionDays: 1,
                    action: .archive,
                    exclusions: .default
                )
            ],
            archive: ArchiveConfig(basePath: nestedArchive.path)
        )

        let output = CleanupEngine().validate(config: config)
        XCTAssertFalse(output.valid)
        XCTAssertTrue(output.issues.contains(where: { $0.contains("must not be inside archive root") }))
    }

    func testValidateFailsWhenArchiveBaseResolvesInsideArchiveRootViaSymlink() throws {
        let rootURL = try makeTemporaryDirectory(named: "fluxus-real-root")
        let aliasContainer = try makeTemporaryDirectory(named: "fluxus-alias-container")
        let aliasRoot = aliasContainer.appendingPathComponent("root-alias", isDirectory: true)
        try FileManager.default.createSymbolicLink(atPath: aliasRoot.path, withDestinationPath: rootURL.path)

        let archiveViaAlias = aliasRoot.appendingPathComponent("archive", isDirectory: true)
        let config = FluxusConfig(
            enabled: false,
            schedule: ScheduleConfig(hour: 1, minute: 0),
            roots: [
                RootRuleConfig(
                    name: "target",
                    path: rootURL.path,
                    retentionDays: 1,
                    action: .archive,
                    exclusions: .default
                )
            ],
            archive: ArchiveConfig(basePath: archiveViaAlias.path)
        )

        let output = CleanupEngine().validate(config: config)
        XCTAssertFalse(output.valid)
        XCTAssertTrue(output.issues.contains(where: { $0.contains("must not be inside archive root") }))
    }

    func testNormalizerRejectsArchiveBaseResolvingInsideArchiveTargetViaSymlink() throws {
        let rootURL = try makeTemporaryDirectory(named: "fluxus-normalize-root")
        let aliasContainer = try makeTemporaryDirectory(named: "fluxus-normalize-alias")
        let aliasRoot = aliasContainer.appendingPathComponent("root-alias", isDirectory: true)
        try FileManager.default.createSymbolicLink(atPath: aliasRoot.path, withDestinationPath: rootURL.path)

        let config = FluxusConfig(
            enabled: false,
            schedule: ScheduleConfig(hour: 1, minute: 0),
            roots: [
                RootRuleConfig(
                    name: "target",
                    path: rootURL.path,
                    retentionDays: 1,
                    action: .archive,
                    exclusions: .default
                )
            ],
            archive: ArchiveConfig(basePath: aliasRoot.appendingPathComponent("archive", isDirectory: true).path)
        )

        XCTAssertThrowsError(
            try FluxusConfigNormalizer.normalize(
                config,
                requireRoots: true,
                validatePaths: true
            )
        ) { error in
            XCTAssertTrue(error.localizedDescription.contains("must not be inside archive target"))
        }
    }

    func testSafetyCheckRejectsCandidateReplacedWithSymlink() throws {
        let rootURL = try makeTemporaryDirectory(named: "fluxus-safety-root")
        let candidateURL = rootURL.appendingPathComponent("candidate.txt")
        let replacementURL = rootURL.appendingPathComponent("replacement.txt")
        try Data("candidate".utf8).write(to: candidateURL)
        try Data("replacement".utf8).write(to: replacementURL)

        let root = RootRuleConfig(
            name: "target",
            path: rootURL.path,
            retentionDays: 1,
            action: .archive,
            exclusions: .default
        )
        let engine = CleanupEngine()
        let identity = try engine.fileIdentity(at: candidateURL.path)
        let candidate = CleanupEngine.Candidate(
            rootIndex: 0,
            root: root,
            url: candidateURL,
            modifiedDate: Date(timeIntervalSince1970: 1_700_000_000),
            sizeBytes: 9,
            identity: identity
        )

        try FileManager.default.removeItem(at: candidateURL)
        try FileManager.default.createSymbolicLink(atPath: candidateURL.path, withDestinationPath: replacementURL.path)

        let canonicalRootPath = engine.canonicalizedFileURL(forPath: root.path).path
        XCTAssertThrowsError(
            try engine.ensureCandidateUnchangedAndWithinRoot(
                candidate,
                rootPath: canonicalRootPath,
                safePrefix: engine.pathPrefix(for: canonicalRootPath)
            )
        )
    }

    func testRunFailsClosedWhenValidationIssuesExist() {
        let missingPath = "/tmp/fluxus-missing-\(UUID().uuidString)"
        let config = FluxusConfig(
            enabled: false,
            schedule: ScheduleConfig(hour: 1, minute: 0),
            roots: [
                RootRuleConfig(
                    name: "missing",
                    path: missingPath,
                    retentionDays: 1,
                    action: .trash,
                    exclusions: .default
                )
            ]
        )

        let output = CleanupEngine().run(config: config)
        XCTAssertEqual(output.processedCount, 0)
        XCTAssertGreaterThan(output.errorCount, 0)
        XCTAssertTrue(output.errors.contains(where: { $0.message.contains("does not exist") }))
    }

    private func makeTemporaryDirectory(named prefix: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        tempDirectories.append(directory)
        return directory
    }

    private func setModificationDate(_ date: Date, for urls: URL...) throws {
        for url in urls {
            try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        }
    }

    private func recursiveFiles(in root: URL) throws -> [URL] {
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: []
        )

        var files: [URL] = []
        while let next = enumerator?.nextObject() as? URL {
            let values = try next.resourceValues(forKeys: [.isRegularFileKey])
            if values.isRegularFile == true {
                files.append(next)
            }
        }
        return files.sorted { $0.path < $1.path }
    }

    private func zipMagicHeader(at fileURL: URL) throws -> [UInt8] {
        let data = try Data(contentsOf: fileURL)
        XCTAssertGreaterThanOrEqual(data.count, 4)
        return Array(data.prefix(4))
    }
}
