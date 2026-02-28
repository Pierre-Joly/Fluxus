import XCTest
@testable import Fluxus

final class DashboardSectionTests: XCTestCase {
    func testDashboardSectionsAreStableAndUnique() {
        let sections = DashboardSection.allCases

        XCTAssertEqual(sections, [.overview, .rules, .simulation, .history])
        XCTAssertEqual(Set(sections.map(\.rawValue)).count, sections.count)
    }

    func testDashboardSectionsHaveNonEmptyTitlesAndIcons() {
        for section in DashboardSection.allCases {
            XCTAssertFalse(section.title.isEmpty)
            XCTAssertFalse(section.systemImage.isEmpty)
        }
    }
}
