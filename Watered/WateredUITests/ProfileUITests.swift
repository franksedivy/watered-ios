//
//  ProfileUITests.swift
//  Watered
//
//  Created by Frank Sedivy on 27/09/2026.
//

import XCTest

final class ProfileUITests: XCTestCase {
    // GIVEN a metric goal, when Profile's display unit changes without closing the sheet,
    // THEN the label immediately converts and switching back preserves the original target.
    @MainActor
    func testChangingDisplayUnitImmediatelyReformatsGoal() {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestingInMemory",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_GB"
        ]
        app.launch()

        let profileButton = app.buttons["profileButton"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 5))
        profileButton.tap()

        let picker = app.segmentedControls["displayUnitPicker"]
        let goalText = app.staticTexts["dailyHydrationGoalText"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3))
        XCTAssertTrue(goalText.waitForExistence(timeout: 3))
        XCTAssertEqual(goalText.label, "Daily goal: 2700 ml")

        let selections = [
            ("US fl oz", "Daily goal: 91 US fl oz"),
            ("imp fl oz", "Daily goal: 95 fl oz"),
            ("ml", "Daily goal: 2700 ml")
        ]
        for (unitLabel, expectedGoal) in selections {
            let unitButton = picker.buttons[unitLabel]
            unitButton.tap()
            XCTAssertTrue(unitButton.wait(for: \.isSelected, toEqual: true, timeout: 3))
            XCTAssertTrue(goalText.wait(for: \.label, toEqual: expectedGoal, timeout: 3))
        }

        app.navigationBars["Profile"].swipeDown()
        XCTAssertTrue(goalText.waitForNonExistence(timeout: 3))
        profileButton.tap()
        XCTAssertTrue(goalText.waitForExistence(timeout: 3))
        XCTAssertEqual(goalText.label, "Daily goal: 2700 ml")
    }

    // GIVEN an isolated app, when the goal is edited several times and Done closes Profile,
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
        let doneButton = profileNavigationBar.buttons["profileDoneButton"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 3))
        doneButton.tap()
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
        let goalText = app.staticTexts["dailyHydrationGoalText"]
        XCTAssertEqual(goalText.label, "Daily goal: 2700 ml")

        usButton.tap()

        XCTAssertTrue(
            usButton.wait(for: \.isSelected, toEqual: true, timeout: 3)
        )
        XCTAssertFalse(saveAlert.exists)
        XCTAssertTrue(
            goalText.wait(for: \.label, toEqual: "Daily goal: 91 US fl oz", timeout: 3)
        )

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
