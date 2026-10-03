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

        let volumeWheel = app.pickerWheels.firstMatch
        XCTAssertTrue(volumeWheel.waitForExistence(timeout: 3))
        volumeWheel.adjust(toPickerWheelValue: "500 ml")

        let submitButton = app.buttons["addDrinkSubmitButton"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 3))
        submitButton.tap()

        let saveAlert = app.alerts["Could not save your drink"]
        XCTAssertTrue(saveAlert.waitForExistence(timeout: 3))
        saveAlert.buttons["OK"].tap()

        XCTAssertTrue(saveAlert.waitForNonExistence(timeout: 3))
        XCTAssertTrue(submitButton.waitForExistence(timeout: 3))
        XCTAssertEqual(volumeWheel.value as? String, "500 ml")

        submitButton.tap()

        XCTAssertTrue(submitButton.waitForNonExistence(timeout: 3))

        let totalAmount = app.staticTexts["todayTotalAmountText"]
        XCTAssertTrue(totalAmount.waitForExistence(timeout: 3))
        XCTAssertTrue(
            totalAmount.wait(for: \.label, toEqual: "500 ml", timeout: 3),
            "Retry should add one 500 ml drink, without retaining the failed insertion."
        )
    }
}
