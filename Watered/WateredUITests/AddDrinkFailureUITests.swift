//
//  AddDrinkFailureUITests.swift
//  Watered
//
//  Created by Frank Sedivy on 03/10/2026.
//

import XCTest

final class AddDrinkFailureUITests: XCTestCase {
    // GIVEN a selected volume, when the first save fails and submission is retried,
    // THEN the alert preserves the form and the successful retry adds only one drink.
    @MainActor
    func testFailedSavePreservesVolumeAndAllowsRetry() {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestingInMemory",
            "-uiTestingFailFirstDrinkSave",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_GB"
        ]
        app.launch()

        let addButton = app.buttons["addDrinkActionButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let coffee = app.scrollViews["addDrinkCategoryScrollView"]
            .buttons["addDrinkCategoryScrollView.coffee"]
        XCTAssertTrue(coffee.wait(for: \.isHittable, toEqual: true, timeout: 10))
        coffee.tap()
        let decaf = app.switches["addDrinkDecafToggle"]
        XCTAssertTrue(decaf.wait(for: \.isHittable, toEqual: true, timeout: 10))
        decaf.tap()
        let shots = app.steppers["addDrinkShotStepper"]
        shots.buttons["addDrinkShotStepper-Increment"].tap()

        let volumeWheel = app.pickerWheels.firstMatch
        XCTAssertTrue(volumeWheel.waitForExistence(timeout: 3))
        volumeWheel.adjust(toPickerWheelValue: "500 ml")

        dismissAddDrinkSheet(in: app)
        changeAddDrinkDisplayUnit(to: "US fl oz", in: app)
        addButton.tap()
        XCTAssertTrue(volumeWheel.waitForExistence(timeout: 10))

        let submitButton = app.buttons["addDrinkSubmitButton"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 3))
        submitButton.tap()

        let saveAlert = app.alerts["Could not save your drink"]
        XCTAssertTrue(saveAlert.waitForExistence(timeout: 3))
        saveAlert.buttons["OK"].tap()

        XCTAssertTrue(saveAlert.waitForNonExistence(timeout: 3))
        XCTAssertTrue(submitButton.waitForExistence(timeout: 3))
        XCTAssertEqual(volumeWheel.value as? String, "16.907 US fl oz")
        dismissAddDrinkSheet(in: app)
        XCTAssertTrue(submitButton.waitForNonExistence(timeout: 10))
        addButton.tap()
        XCTAssertTrue(decaf.waitForExistence(timeout: 10))
        XCTAssertEqual(decaf.value as? String, "1")
        XCTAssertEqual(shots.value as? String, "3")
        XCTAssertEqual(volumeWheel.value as? String, "16.907 US fl oz")

        submitButton.tap()

        XCTAssertTrue(submitButton.waitForNonExistence(timeout: 3))

        changeAddDrinkDisplayUnit(to: "ml", in: app)
        let totalAmount = app.staticTexts["todayTotalAmountText"]
        XCTAssertTrue(totalAmount.waitForExistence(timeout: 3))
        XCTAssertTrue(
            totalAmount.wait(for: \.label, toEqual: "500 ml", timeout: 3),
            "Retry should add one 500 ml drink, without retaining the failed insertion."
        )
    }
}
