import XCTest

/// Isolated storage and fake permissions only; never opens a real Health authorization sheet.
final class HealthSyncUITests: XCTestCase {
    /// Opens the production screen against a fake client and a disposable store.
    @MainActor
    private func openHealth(_ scenario: String, largeText: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingInMemory", "-uiTestingHealth=\(scenario)", "-AppleLanguages", "(en)", "-AppleLocale", "en_GB"]
        app.launchArguments += ["-UIPreferredContentSizeCategoryName",
                                largeText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
        app.launch()
        let profile = app.buttons["profileButton"]
        XCTAssertTrue(profile.waitForExistence(timeout: 5))
        profile.tap()
        let link = app.buttons.matching(NSPredicate(format: "label IN %@", ["Apple Health", "Sync with Apple Health"])).firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 3))
        link.tap()
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
        tapToggle(toggle)
        XCTAssertEqual(toggle.value as? String, "1")
        XCTAssertFalse(app.staticTexts["Connected"].exists)
        tapToggle(toggle)
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertFalse(app.buttons["healthReviewPermissions"].exists)
        tapToggle(toggle)
        revealReview(in: app)
        app.buttons["Review permissions"].tap()
        XCTAssertTrue(app.alerts["Apple Health permissions"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.alerts.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Open Health")).firstMatch.exists)
    }

    // Given unavailable Health, reviewing permissions preserves the local-logging promise.
    @MainActor
    func testUnavailablePermissionExplainsLocalLogging() {
        let app = openHealth("unavailable")
        tapToggle(app.switches["healthSyncToggle"])
        revealReview(in: app)
        app.buttons["Review permissions"].tap()
        XCTAssertTrue(app.alerts.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "You can still log drinks")).firstMatch.waitForExistence(timeout: 3))
    }

    // Given a restricted request, the screen explains the error without changing app opt-in.
    @MainActor
    func testRestrictedRequestPreservesSyncChoice() {
        let app = openHealth("restricted")
        tapToggle(app.switches["healthSyncToggle"])
        revealReview(in: app)
        app.buttons["Review permissions"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Health access is restricted")).firstMatch.waitForExistence(timeout: 3))
        app.swipeDown()
        app.swipeDown()
        XCTAssertEqual(app.switches["healthSyncToggle"].value as? String, "1")
    }

    // A saved opt-in survives leaving the detail screen; permission request completion
    // must preserve mixed per-type results rather than manufacturing a Connected state.
    @MainActor
    func testMixedPermissionsAndPreferenceSurviveReopening() {
        let app = openHealth("mixed")
        XCTAssertFalse(app.buttons["healthReviewPermissions"].exists)
        XCTAssertFalse(app.buttons["healthSyncRetry"].exists)
        XCTAssertFalse(app.buttons["healthExportStatusLink"].exists)
        capture("Apple Health — disabled", in: app)
        tapToggle(app.switches["healthSyncToggle"])
        revealReview(in: app)
        app.buttons["healthReviewPermissions"].tap()
        for (type, value) in [("water", "Allowed"), ("caffeine", "Not allowed"), ("alcohol", "Not requested")] {
            let permission = app.descendants(matching: .any)["healthPermission-\(type)"].firstMatch
            XCTAssertEqual(permission.value as? String, value)
        }
        XCTAssertFalse(app.staticTexts["Connected"].exists)
        capture("Apple Health — mixed permissions", in: app)
        app.navigationBars["Apple Health"].buttons.element(boundBy: 0).tap()
        app.buttons["Apple Health"].tap()
        XCTAssertEqual(app.switches["healthSyncToggle"].value as? String, "1")
    }

    // A failed transaction must leave the toggle off and explain recovery; retrying
    // the deliberate edit succeeds without a system permission sheet.
    @MainActor
    func testFailedPreferenceSavePreservesChoiceAndCanRetry() {
        let app = openHealth("saveFailure")
        tapToggle(app.switches["healthSyncToggle"])
        XCTAssertEqual(app.switches["healthSyncToggle"].value as? String, "0")
        let error = app.staticTexts["Could not save your sync preference. It has not changed."]
        reveal(error, in: app)
        XCTAssertTrue(error.exists)
        reveal(app.switches["healthSyncToggle"], in: app, upwards: false)
        tapToggle(app.switches["healthSyncToggle"])
        XCTAssertEqual(app.switches["healthSyncToggle"].value as? String, "1")
    }

    // Real Retry now processes only retryable work. Acknowledged caffeine and invalid
    // alcohol remain independent, and the screen refreshes after the fake write returns.
    @MainActor
    func testRetryUpdatesFailedTypeWithoutChangingOtherOutcomes() {
        let app = openHealth("retry")
        openExportStatus(in: app)
        let water = app.descendants(matching: .any)["healthExportStatus-water"].firstMatch
        reveal(water, in: app)
        XCTAssertTrue(water.label.contains("Waiting to retry: 1"))
        let caffeine = app.descendants(matching: .any)["healthExportStatus-caffeine"].firstMatch
        let alcohol = app.descendants(matching: .any)["healthExportStatus-alcohol"].firstMatch
        reveal(alcohol, in: app)
        XCTAssertTrue(caffeine.label.contains("Sent to Apple Health: 1"))
        XCTAssertTrue(alcohol.label.contains("Could not send: 1"))
        let retry = app.buttons["healthSyncRetry"]
        reveal(retry, in: app)
        retry.tap()
        reveal(water, in: app, upwards: false)
        assertEventually(water, "label CONTAINS %@", "Sent to Apple Health: 1")
        XCTAssertTrue(caffeine.label.contains("Sent to Apple Health: 1"))
    }

    // Disabled sync hides the upload controls. Enabling reveals previously eligible
    // pending work, and Retry now sends it without inventing a historical export.
    @MainActor
    func testPendingUploadsStayPausedUntilEnabled() {
        let app = openHealth("paused")
        XCTAssertFalse(app.buttons["healthSyncRetry"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["healthExportStatus-water"].firstMatch.exists)
        XCTAssertFalse(app.buttons["healthExportStatusLink"].exists)
        tapToggle(app.switches["healthSyncToggle"])
        openExportStatus(in: app)
        let water = app.descendants(matching: .any)["healthExportStatus-water"].firstMatch
        reveal(water, in: app)
        XCTAssertTrue(water.label.contains("Pending: 1"))
        let retry = app.buttons["healthSyncRetry"]
        reveal(retry, in: app)
        retry.tap()
        reveal(water, in: app, upwards: false)
        assertEventually(water, "label CONTAINS %@", "Sent to Apple Health: 1")
        app.navigationBars["Export status"].buttons.element(boundBy: 0).tap()
        tapToggle(app.switches["healthSyncToggle"])
        XCTAssertTrue(app.buttons["healthExportStatusLink"].waitForNonExistence(timeout: 3))
    }

    // Cleanup stays actionable on the main screen while uploads are off; the
    // information destination contains prose only, with no duplicate settings.
    @MainActor
    func testBlockedCleanupRemainsReachableWhileSyncIsOff() {
        let app = openHealth("cleanup")
        let blocked = app.staticTexts["Deleted from Watered. To remove its Apple Health data, restore permission or delete it in Health."]
        reveal(blocked, in: app)
        XCTAssertTrue(blocked.exists)
        let retry = app.buttons["healthCleanupRetry"]
        reveal(retry, in: app)
        retry.tap()
        reveal(app.switches["healthSyncToggle"], in: app, upwards: false)
        XCTAssertEqual(app.switches["healthSyncToggle"].value as? String, "0")
        reveal(app.buttons["healthSyncInformation"], in: app)
        app.buttons["healthSyncInformation"].tap()
        XCTAssertTrue(app.staticTexts["About syncing"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["healthManagePermissions"].exists)
        XCTAssertFalse(app.buttons["healthCleanupRetry"].exists)
        capture("Apple Health plain information", in: app)
    }

    // At the largest accessibility size, essential controls and privacy copy remain
    // reachable. This does not replace spoken VoiceOver or visual contrast review.
    @MainActor
    func testLargestTextKeepsControlsAndPrivacyReachable() {
        let app = openHealth("mixed", largeText: true)
        tapToggle(app.switches["healthSyncToggle"])
        assertEventually(app.switches["healthSyncToggle"], "value == %@", "1")
        revealReview(in: app)
        XCTAssertTrue(app.buttons["healthReviewPermissions"].isHittable)
        openExportStatus(in: app)
        let retry = app.buttons["healthSyncRetry"]
        reveal(retry, in: app)
        XCTAssertTrue(retry.isHittable)
        capture("Apple Health export status at largest text", in: app)
        app.navigationBars["Export status"].buttons.element(boundBy: 0).tap()
        reveal(app.buttons["healthSyncInformation"], in: app)
        app.buttons["healthSyncInformation"].tap()
        let privacy = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "Watered requests write access only")).firstMatch
        reveal(privacy, in: app, maxSwipes: 30)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Apple Health privacy at largest text"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// Exercises the production navigation rather than mounting a status-only test view.
    @MainActor
    private func openExportStatus(in app: XCUIApplication) {
        let link = app.buttons["healthExportStatusLink"]
        reveal(link, in: app)
        link.tap()
        XCTAssertTrue(app.navigationBars["Export status"].waitForExistence(timeout: 3))
    }

    /// Retains visual evidence for the focused screen review without reading personal data.
    @MainActor
    private func capture(_ name: String, in app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// SwiftUI exposes the full labelled row as a switch. Tap its trailing control,
    /// since tapping the label's centre does not operate the native switch on iOS 27.2.
    @MainActor
    private func tapToggle(_ toggle: XCUIElement) {
        XCTAssertTrue(toggle.wait(for: \.isEnabled, toEqual: true, timeout: 3))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    }

    /// Waits for asynchronous presentation without depending on SwiftUI's label separator.
    @MainActor
    private func assertEventually(_ element: XCUIElement, _ format: String, _ value: String) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: format, value), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }

    /// Brings controls clear of navigation chrome before tapping. XCTest can report
    /// a Form button as hittable even when its centre lies behind the navigation bar.
    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, upwards: Bool = true, maxSwipes: Int = 10) {
        for _ in 0..<maxSwipes {
            var scrollUp = upwards
            if element.exists {
                let centre = element.frame.midY
                let top = app.navigationBars.firstMatch.frame.maxY + 10
                let bottom = app.frame.maxY - 35
                let isControl = element.elementType == .button || element.elementType == .switch
                if element.isHittable && (!isControl || (centre > top && centre < bottom)) { return }
                if isControl { scrollUp = centre >= bottom }
            }
            if scrollUp { app.swipeUp() } else { app.swipeDown() }
        }
        XCTFail("Could not reach \(element)")
    }

    /// Uses the same visibility rule for initial and previously scrolled permission controls.
    @MainActor
    private func revealReview(in app: XCUIApplication) {
        reveal(app.buttons["healthReviewPermissions"], in: app, maxSwipes: 12)
    }
}
