import SwiftUI
import XCTest
@testable import Fluxus
#if canImport(AppKit)
import AppKit
#endif

@MainActor
final class AppAppearanceTests: XCTestCase {
    func testColorSchemeMapping() {
        XCTAssertNil(AppAppearance.system.colorScheme)
        XCTAssertEqual(AppAppearance.black.colorScheme, .dark)
        XCTAssertEqual(AppAppearance.white.colorScheme, .light)
    }

#if canImport(AppKit)
    func testNSAppearanceMapping() {
        XCTAssertNil(AppAppearance.system.nsAppearanceName)
        XCTAssertEqual(AppAppearance.black.nsAppearanceName, .darkAqua)
        XCTAssertEqual(AppAppearance.white.nsAppearanceName, .aqua)
    }

    func testAppearanceManagerAppliesAndResetsAppAndWindowAppearance() {
        let window = MockAppearanceWindow()
        let application = MockAppearanceApplication(windows: [window])
        application.appearance = NSAppearance(named: .darkAqua)

        AppAppearanceManager.apply(.white, application: application)
        XCTAssertNil(application.appearance)
        XCTAssertEqual(window.appearance?.name, .aqua)
        XCTAssertEqual(window.refreshCount, 1)

        AppAppearanceManager.apply(.black, application: application)
        XCTAssertNil(application.appearance)
        XCTAssertEqual(window.appearance?.name, .darkAqua)
        XCTAssertEqual(window.refreshCount, 2)

        AppAppearanceManager.apply(.system, application: application)
        XCTAssertNil(application.appearance)
        XCTAssertNil(window.appearance)
        XCTAssertEqual(window.refreshCount, 3)
    }
#endif

    func testLoadAndPersistAppearanceInUserDefaults() {
        let suiteName = "FluxusTests.AppAppearance.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Unable to create isolated UserDefaults suite")
            return
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        XCTAssertEqual(AppAppearance.load(from: defaults), .system)

        AppAppearance.black.persist(to: defaults)
        XCTAssertEqual(AppAppearance.load(from: defaults), .black)

        defaults.set("invalid-value", forKey: FluxusViewModelConstants.appearanceDefaultsKey)
        XCTAssertEqual(AppAppearance.load(from: defaults), .system)
    }
}

#if canImport(AppKit)
@MainActor
private final class MockAppearanceWindow: AppearanceManagingWindow {
    var appearance: NSAppearance?
    var refreshCount: Int = 0

    func refreshForAppearanceChange() {
        refreshCount += 1
    }
}

@MainActor
private final class MockAppearanceApplication: AppearanceManagingApplication {
    var appearance: NSAppearance?
    var appearanceManagedWindows: [AppearanceManagingWindow]

    init(windows: [AppearanceManagingWindow]) {
        appearanceManagedWindows = windows
    }
}
#endif
