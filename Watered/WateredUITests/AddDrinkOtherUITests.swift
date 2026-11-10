import XCTest

final class AddDrinkOtherUITests: XCTestCase {
    @MainActor
    func testOtherServingDefaultsAndManualAmountAreSavedWithoutPreparation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingInMemory", "-AppleLanguages", "(en)", "-AppleLocale", "en_GB"]
        app.launch()
        app.buttons["addDrinkActionButton"].tap()
        let categories = app.scrollViews["addDrinkCategoryScrollView"]
        let other = categories.buttons["addDrinkCategoryScrollView.other"]
        for _ in 0..<16 {
            if other.isHittable { break }
            categories.swipeLeft()
        }
        XCTAssertTrue(other.wait(for: \.isHittable, toEqual: true, timeout: 10))
        other.tap()
        let broth = app.buttons["addDrinkTypeScrollView.broth"]
        let miso = app.buttons["addDrinkTypeScrollView.miso"]
        XCTAssertTrue(broth.wait(for: \.isSelected, toEqual: true, timeout: 10))
        XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, "250 ml")
        XCTAssertTrue(miso.wait(for: \.isHittable, toEqual: true, timeout: 10))
        miso.tap()
        XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, "250 ml")
        for id in ["addDrinkDecafToggle", "addDrinkCaffeineFreeToggle", "addDrinkNonAlcoholicToggle"] {
            XCTAssertFalse(app.switches[id].exists)
        }
        XCTAssertFalse(app.steppers["addDrinkShotStepper"].exists)
        XCTAssertFalse(app.sliders["addDrinkABVSlider"].exists)
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "500 ml")
        broth.tap()
        XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, "500 ml")
        dismissAddDrinkSheet(in: app)
        app.buttons["addDrinkActionButton"].tap()
        XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, "500 ml")
        miso.tap()
        XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, "500 ml")
        app.buttons["addDrinkSubmitButton"].tap()
        XCTAssertTrue(app.buttons["addDrinkSubmitButton"].waitForNonExistence(timeout: 10))
        app.tabBars.buttons["Stats"].tap()
        let row = app.collectionViews["statsDrinkHistoryList"].buttons["statsDrinkEntryLink"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        let detail = app.collectionViews["statsDrinkEntryDetailList"]
        XCTAssertTrue(detail.waitForExistence(timeout: 10))
        XCTAssertTrue(detail.staticTexts["statsDrinkAmount"].label.contains("500 ml"))
        XCTAssertTrue(detail.staticTexts["statsHydrationContribution"].label.contains("475 ml"))
    }
}
