import AppKit
import XCTest

final class FluxusUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        terminateStaleFluxusProcesses()
    }

    override func tearDownWithError() throws {
        XCUIApplication().terminate()
        try super.tearDownWithError()
    }

    @MainActor
    func testSidebarSectionsAreClickable() throws {
        let app = launchDashboard()
        let overviewSummary = app.staticTexts["overview-summary-text"]

        selectSidebarSection("overview", expectedControl: overviewSummary, in: app)
        selectSidebarSection("rules", expectedControl: app.buttons["Add Folder Target"], in: app)
        selectSidebarSection("simulation", expectedControl: app.buttons["Run Simulation"], in: app)
        selectSidebarSection("history", expectedControl: app.buttons["Refresh"], in: app)
        selectSidebarSection("overview", expectedControl: overviewSummary, in: app)
    }

    @MainActor
    func testTargetsPanelAllowsEditingFolderPath() throws {
        let app = launchDashboard()

        selectSidebarSection("rules", expectedControl: app.buttons["Add Folder Target"], in: app)

        let addButton = app.buttons["Add Folder Target"]
        addButton.click()

        let folderField = app.textFields["target-folder-path-field"]
        XCTAssertTrue(folderField.waitForExistence(timeout: 5))
        XCTAssertTrue(folderField.isHittable, "Folder field should remain visible in Targets pane")

        let chooseFolderButton = app.buttons["target-choose-folder-button"]
        XCTAssertTrue(chooseFolderButton.waitForExistence(timeout: 5))
        XCTAssertTrue(chooseFolderButton.isHittable, "Choose folder button should not collapse out of view")

        app.activate()
        replaceText(in: folderField, with: "/tmp/fluxus-ui-test")
        XCTAssertEqual(folderField.value as? String, "/tmp/fluxus-ui-test")
    }

    @MainActor
    func testFirstRunScreenShowsWhenAcknowledgementIsForcedOff() throws {
        let app = XCUIApplication()
        app.launchEnvironment["FLUXUS_TEST_FIRST_RUN_ACKNOWLEDGED"] = "0"
        app.launchArguments += [
            "-ApplePersistenceIgnoreState", "YES",
            "-Fluxus.FirstRunAcknowledged", "NO"
        ]
        app.launch()

        ensureFirstRunWindow(in: app)
        XCTAssertTrue(app.staticTexts["Welcome to Fluxus"].waitForExistence(timeout: 8))
        let checkbox = app.checkBoxes["I understand"]
        if checkbox.waitForExistence(timeout: 2) {
            XCTAssertTrue(checkbox.exists)
        } else {
            XCTAssertTrue(app.switches["I understand"].waitForExistence(timeout: 5))
        }
    }

    @MainActor
    private func launchDashboard() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FLUXUS_TEST_FIRST_RUN_ACKNOWLEDGED"] = "1"
        app.launchArguments += [
            "-ApplePersistenceIgnoreState", "YES",
            "-Fluxus.FirstRunAcknowledged", "YES"
        ]
        app.launch()
        ensureDashboardWindow(in: app)
        return app
    }

    @MainActor
    private func selectSidebarSection(
        _ rawSection: String,
        expectedControl: XCUIElement,
        in app: XCUIApplication
    ) {
        let sidebarItem = app.descendants(matching: .any)["sidebar-section-\(rawSection)"]
        if !sidebarItem.waitForExistence(timeout: 3) {
            ensureDashboardWindow(in: app)
        }
        XCTAssertTrue(sidebarItem.waitForExistence(timeout: 5))
        sidebarItem.click()
        XCTAssertTrue(expectedControl.waitForExistence(timeout: 5))
    }

    @MainActor
    private func replaceText(in field: XCUIElement, with value: String) {
        field.click()
        field.click()
        field.typeKey("a", modifierFlags: [.command])
        field.typeKey(XCUIKeyboardKey.delete.rawValue, modifierFlags: [])
        field.typeText(value)
    }

    @MainActor
    private func ensureDashboardWindow(in app: XCUIApplication) {
        let sidebarAnchor = app.descendants(matching: .any)["sidebar-section-overview"]
        for _ in 0..<3 {
            if sidebarAnchor.waitForExistence(timeout: 2) {
                return
            }
            app.activate()
            app.typeKey("n", modifierFlags: [.command])
        }
        XCTAssertTrue(sidebarAnchor.waitForExistence(timeout: 5))
    }

    @MainActor
    private func ensureFirstRunWindow(in app: XCUIApplication) {
        let welcome = app.staticTexts["Welcome to Fluxus"]
        if welcome.waitForExistence(timeout: 2) {
            return
        }

        app.activate()
        app.typeKey("n", modifierFlags: [.command])
        XCTAssertTrue(welcome.waitForExistence(timeout: 8))
    }

    private func terminateStaleFluxusProcesses() {
        let bundleIdentifiers = ["com.pierre.Fluxus", "com.pierre.Fluxus.debug"]
        for bundleIdentifier in bundleIdentifiers {
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)

            for app in running {
                _ = app.terminate()

                let deadline = Date().addingTimeInterval(2)
                while !app.isTerminated && Date() < deadline {
                    _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
                }

                if !app.isTerminated {
                    app.forceTerminate()
                }
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        process.arguments = ["-f", "Fluxus.app/Contents/MacOS/Fluxus"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
    }
}
