import Foundation
import XCTest
@testable import Fluxus

final class CleanupEngineHelperTests: XCTestCase {
    private var tempDirectories: [URL] = []

    override func tearDownWithError() throws {
        for directory in tempDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        tempDirectories.removeAll()
        try super.tearDownWithError()
    }

    func testUniqueDestinationAddsNumericSuffixOnCollisions() throws {
        let directory = try makeTemporaryDirectory(named: "fluxus-unique-destination")

        let base = directory.appendingPathComponent("report.txt")
        let firstCollision = directory.appendingPathComponent("report (1).txt")
        try Data().write(to: base)
        try Data().write(to: firstCollision)

        let candidate = CleanupEngine().uniqueDestination(for: "report.txt", in: directory)
        XCTAssertEqual(candidate.lastPathComponent, "report (2).txt")
    }

    func testArchiveRunOutputFileNameUsesZipExtensionAndStablePrefix() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let output = CleanupEngine().archiveRunOutputFileName(for: date)
        XCTAssertTrue(output.hasPrefix("fluxus-archive-run-"))
        XCTAssertTrue(output.hasSuffix(".zip"))
    }

    private func makeTemporaryDirectory(named prefix: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        tempDirectories.append(directory)
        return directory
    }
}
