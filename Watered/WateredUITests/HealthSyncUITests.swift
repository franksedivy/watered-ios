import XCTest

/// Isolated storage and fake permissions only; never opens a real Health authorization sheet.
final class HealthSyncUITests: XCTestCase {
    /// Opens the production screen against a fake client and a disposable store.
    @MainActor
    private func openHealth(_ scenario: String) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingInMemory", "-uiTestingHealth=\(scenario)", "-AppleLanguages", "(en)", "-AppleLocale", "en_GB"]
        app.launch()
        let profile = app.buttons["profileButton"]
        XCTAssertTrue(profile.waitForExistence(timeout: 5))
        profile.tap()
        app.buttons["Sync with Apple Health"].tap()
        XCTAssertTrue(app.switches["healthSyncToggle"].waitForExistence(timeout: 3))
        return app
    }

    // Given denied write access, the app preference remains editable and permission
    // recovery explains the Health-app route without claiming a connection.
    @MainActor
    func testDeniedPermissionsDoNotControlAppPreference() {
        let app = openHealth("denied")
        let toggle = app.switches["healthSyncToggle"]
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        XCTAssertFalse(app.staticTexts["Connected"].exists)
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "0")
        revealReview(in: app)
        app.buttons["Review permissions"].tap()
        XCTAssertTrue(app.alerts["Apple Health permissions"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.alerts.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Open Health")).firstMatch.exists)
    }

    // Given unavailable Health, reviewing permissions preserves the local-logging promise.
    @MainActor
    func testUnavailablePermissionExplainsLocalLogging() {
        let app = openHealth("unavailable")
        revealReview(in: app)
        app.buttons["Review permissions"].tap()
        XCTAssertTrue(app.alerts.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "You can still log drinks")).firstMatch.waitForExistence(timeout: 3))
    }

    // Given a restricted request, the screen explains the error without opting in.
    @MainActor
    func testRestrictedRequestShowsErrorWithoutEnablingSync() {
        let app = openHealth("restricted")
        revealReview(in: app)
        app.buttons["Review permissions"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Health access is restricted")).firstMatch.waitForExistence(timeout: 3))
        app.swipeDown()
        app.swipeDown()
        XCTAssertEqual(app.switches["healthSyncToggle"].value as? String, "0")
    }

    /// Scrolls through the explanatory copy without relying on a fixed screen height.
    @MainActor
    private func revealReview(in app: XCUIApplication) {
        for _ in 0..<5 {
            if app.buttons["Review permissions"].isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(app.buttons["Review permissions"].isHittable)
    }
}
