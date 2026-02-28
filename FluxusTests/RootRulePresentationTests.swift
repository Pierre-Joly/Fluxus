import XCTest
@testable import Fluxus

final class RootRulePresentationTests: XCTestCase {
    func testDisplayNameUsesExplicitName() {
        let root = RootRuleConfig(
            name: "Downloads Sweep",
            path: "~/Downloads",
            retentionDays: 30,
            action: .trash,
            exclusions: .default
        )

        XCTAssertEqual(root.displayName, "Downloads Sweep")
    }

    func testDisplayNameFallsBackToFolderName() {
        let root = RootRuleConfig(
            name: "  ",
            path: "~/scratch",
            retentionDays: 7,
            action: .trash,
            exclusions: .default
        )

        XCTAssertEqual(root.displayName, "scratch")
    }

    func testDisplayNameFallsBackToUntitledWhenNameAndPathAreEmpty() {
        let root = RootRuleConfig(
            name: " ",
            path: " ",
            retentionDays: 7,
            action: .trash,
            exclusions: .default
        )

        XCTAssertEqual(root.displayName, "Untitled Target")
    }

    func testNormalizerUsesFolderNameWhenNameMissing() throws {
        let config = FluxusConfig(
            enabled: false,
            schedule: ScheduleConfig(hour: 10, minute: 30),
            roots: [
                RootRuleConfig(
                    name: "",
                    path: "/tmp/FluxusTarget",
                    retentionDays: 5,
                    action: .trash,
                    exclusions: .default
                )
            ]
        )

        let normalized = try FluxusConfigNormalizer.normalize(
            config,
            requireRoots: false,
            validatePaths: false
        )

        XCTAssertEqual(normalized.roots.first?.name, "FluxusTarget")
    }
}
