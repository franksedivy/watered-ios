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
        let link = app.buttons["Sync with Apple Health"]
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

    // A saved opt-in survives leaving the detail screen; permission request completion
    // must preserve mixed per-type results rather than manufacturing a Connected state.
    @MainActor
    func testMixedPermissionsAndPreferenceSurviveReopening() {
        let app = openHealth("mixed")
        tapToggle(app.switches["healthSyncToggle"])
        revealReview(in: app)
        app.buttons["healthReviewPermissions"].tap()
        for (type, value) in [("water", "Allowed"), ("caffeine", "Not allowed"), ("alcohol", "Not requested")] {
            let permission = app.descendants(matching: .any)["healthPermission-\(type)"].firstMatch
            XCTAssertEqual(permission.value as? String, value)
        }
        XCTAssertFalse(app.staticTexts["Connected"].exists)
        app.navigationBars["Apple Health"].buttons.element(boundBy: 0).tap()
        app.buttons["Sync with Apple Health"].tap()
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

    // Turning sync off pauses pending uploads; Retry now cannot bypass the preference.
    @MainActor
    func testPendingUploadsStayPausedUntilEnabled() {
        let app = openHealth("paused")
        let water = app.descendants(matching: .any)["healthExportStatus-water"].firstMatch
        reveal(water, in: app)
        XCTAssertTrue(water.label.contains("Paused: 1"))
        let retry = app.buttons["healthSyncRetry"]
        reveal(retry, in: app)
        retry.tap()
        reveal(water, in: app, upwards: false)
        XCTAssertTrue(water.label.contains("Paused: 1"))
        reveal(app.switches["healthSyncToggle"], in: app, upwards: false)
        tapToggle(app.switches["healthSyncToggle"])
        reveal(water, in: app)
        XCTAssertTrue(water.label.contains("Pending: 1"))
        reveal(retry, in: app)
        retry.tap()
        reveal(water, in: app, upwards: false)
        assertEventually(water, "label CONTAINS %@", "Sent to Apple Health: 1")
    }

    // Blocked deletion remains visible with sync off. Restored fake permission plus
    // Retry now resolves cleanup through the worker without enabling uploads.
    @MainActor
    func testBlockedCleanupRecoversWhileSyncRemainsOff() {
        let app = openHealth("cleanup")
        let blocked = app.staticTexts["Deleted from Watered. To remove its Apple Health data, restore permission or delete it in Health."]
        reveal(blocked, in: app)
        XCTAssertTrue(blocked.exists)
        let review = app.buttons["healthReviewPermissions"]
        reveal(review, in: app, upwards: false)
        review.tap()
        let waterPermission = app.descendants(matching: .any)["healthPermission-water"].firstMatch
        reveal(waterPermission, in: app, upwards: false)
        assertEventually(waterPermission, "value == %@", "Allowed")
        let retry = app.buttons["healthCleanupRetry"]
        reveal(retry, in: app)
        retry.tap()
        XCTAssertTrue(blocked.waitForNonExistence(timeout: 5))
        reveal(app.switches["healthSyncToggle"], in: app, upwards: false)
        XCTAssertEqual(app.switches["healthSyncToggle"].value as? String, "0")
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
        let retry = app.buttons["healthSyncRetry"]
        reveal(retry, in: app)
        XCTAssertTrue(retry.isHittable)
        let privacy = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "Watered requests write access only")).firstMatch
        reveal(privacy, in: app, maxSwipes: 30)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Apple Health privacy at largest text"
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
