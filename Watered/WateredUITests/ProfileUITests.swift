//
//  ProfileUITests.swift
//  Watered
//
//  Created by Frank Sedivy on 27/09/2026.
//

import XCTest

final class ProfileUITests: XCTestCase {
    // GIVEN an isolated app, when the goal is edited several times and Profile is dismissed,
    // THEN reopening Profile shows the final selected goal.
    @MainActor
    func testDismissingProfileCommitsFinalGoal() throws {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestingInMemory",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_GB"
        ]
        app.launch()

        let profileButton = app.buttons["profileButton"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 3))
        profileButton.tap()

        let goalText = app.staticTexts["dailyHydrationGoalText"]
        XCTAssertTrue(goalText.waitForExistence(timeout: 3))
        XCTAssertEqual(goalText.label, "Daily goal: 2700 ml")

        let incrementButton = app.steppers["dailyHydrationGoalStepper"]
            .buttons["dailyHydrationGoalStepper-Increment"]
        XCTAssertTrue(incrementButton.waitForExistence(timeout: 3))

        incrementButton.tap()
        incrementButton.tap()
        incrementButton.tap()

        XCTAssertTrue(
            goalText.wait(for: \.label, toEqual: "Daily goal: 3000 ml", timeout: 3)
        )

        let profileNavigationBar = app.navigationBars["Profile"]
        XCTAssertTrue(profileNavigationBar.waitForExistence(timeout: 3))
        profileNavigationBar.swipeDown()
        XCTAssertTrue(goalText.waitForNonExistence(timeout: 3))

        XCTAssertTrue(profileButton.waitForExistence(timeout: 3))
        profileButton.tap()

        XCTAssertTrue(goalText.waitForExistence(timeout: 3))
        XCTAssertTrue(
            goalText.wait(for: \.label, toEqual: "Daily goal: 3000 ml", timeout: 3)
        )
    }
    
    // GIVEN saved metric settings, when the first unit save fails,
    // THEN Profile retains the previous selection and allows a successful retry.
    @MainActor
    func testFailedDisplayUnitSavePreservesSelectionAndAllowsRetry() {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestingInMemory",
            "-uiTestingFailFirstDisplayUnitSave",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_GB"
        ]
        app.launch()

        let profileButton = app.buttons["profileButton"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 5))
        profileButton.tap()

        let picker = app.segmentedControls["displayUnitPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3))

        let metricButton = picker.buttons["ml"]
        let usButton = picker.buttons["US fl oz"]
        XCTAssertTrue(metricButton.isSelected)
        usButton.tap()

        let saveAlert = app.alerts["Could not save your display unit"]
        XCTAssertTrue(saveAlert.waitForExistence(timeout: 3))
        saveAlert.buttons["OK"].tap()
        XCTAssertTrue(saveAlert.waitForNonExistence(timeout: 3))

        XCTAssertTrue(picker.waitForExistence(timeout: 3))
        XCTAssertTrue(
            metricButton.wait(for: \.isSelected, toEqual: true, timeout: 3)
        )
        XCTAssertFalse(usButton.isSelected)

        usButton.tap()

        XCTAssertTrue(
            usButton.wait(for: \.isSelected, toEqual: true, timeout: 3)
        )
        XCTAssertFalse(saveAlert.exists)

        let navigationBar = app.navigationBars["Profile"]
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 3))
        navigationBar.swipeDown()
        XCTAssertTrue(picker.waitForNonExistence(timeout: 3))

        XCTAssertTrue(profileButton.waitForExistence(timeout: 3))
        profileButton.tap()

        XCTAssertTrue(picker.waitForExistence(timeout: 3))
        XCTAssertTrue(
            usButton.wait(for: \.isSelected, toEqual: true, timeout: 3)
        )
    }
}
