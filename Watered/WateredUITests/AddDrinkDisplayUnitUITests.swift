import XCTest

final class AddDrinkDisplayUnitUITests: XCTestCase {
    @MainActor
    func testRecentMenuConvertsAndRepeatPreservesVolumeAndPreparation() {
        let app = launchApp()
        logCoffee(in: app)
        changeAddDrinkDisplayUnit(to: "US fl oz", in: app)
        app.buttons["addDrinkActionButton"].press(forDuration: 1)
        let recent = app.buttons["16.907 US fl oz of Latte (Decaf), 3 shots"]
        XCTAssertTrue(recent.waitForExistence(timeout: 10))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Recent menu in applied US units"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        recent.tap()
        XCTAssertTrue(recent.waitForNonExistence(timeout: 10))
        changeAddDrinkDisplayUnit(to: "ml", in: app)
        XCTAssertTrue(app.staticTexts["todayTotalAmountText"].wait(
            for: \.label, toEqual: "1000 ml", timeout: 10
        ))
        app.tabBars.buttons["Stats"].tap()
        let history = app.collectionViews["statsDrinkHistoryList"]
        XCTAssertTrue(history.waitForExistence(timeout: 10))
        let rows = history.buttons.matching(identifier: "statsDrinkEntryLink")
        XCTAssertEqual(rows.count, 2)
        for row in rows.allElementsBoundByIndex {
            XCTAssertTrue(row.label.contains("500 ml"))
        }
        rows.firstMatch.tap()
        let detail = app.collectionViews["statsDrinkEntryDetailList"]
        XCTAssertTrue(detail.waitForExistence(timeout: 10))
        XCTAssertTrue(detail.staticTexts["statsCaffeinePreparation"].label.contains("Decaf"))
        XCTAssertTrue(detail.staticTexts["statsCaffeineShotCount"].label.contains("3"))
    }

    @MainActor
    func testFailedProfileUnitSaveLeavesDraftAndRecentMenuInAppliedUnit() {
        let app = launchApp(failsUnitSave: true)
        logCoffee(in: app)
        app.buttons["addDrinkActionButton"].tap()
        XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 10))
        app.buttons["addDrinkCategoryScrollView.water"].tap()
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "750 ml")
        dismissAddDrinkSheet(in: app)
        changeAddDrinkDisplayUnit(to: "US fl oz", in: app, fails: true)
        app.buttons["addDrinkActionButton"].tap()
        XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, "750 ml")
        dismissAddDrinkSheet(in: app)
        app.buttons["addDrinkActionButton"].press(forDuration: 1)
        let recent = app.buttons["500 ml of Latte (Decaf), 3 shots"]
        XCTAssertTrue(recent.waitForExistence(timeout: 10))
        recent.tap()
        XCTAssertTrue(recent.waitForNonExistence(timeout: 10))
        // A successful shortcut clears the retained draft, even after a failed settings save.
        app.buttons["addDrinkActionButton"].tap()
        XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, "330 ml")
        XCTAssertFalse(app.buttons["addDrinkSubmitButton"].isEnabled)
    }

    @MainActor
    private func launchApp(failsUnitSave: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingInMemory", "-AppleLanguages", "(en)", "-AppleLocale", "en_GB"]
        if failsUnitSave { app.launchArguments.append("-uiTestingFailFirstDisplayUnitSave") }
        app.launch()
        XCTAssertTrue(app.buttons["addDrinkActionButton"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func logCoffee(in app: XCUIApplication) {
        app.buttons["addDrinkActionButton"].tap()
        XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 10))
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "500 ml")
        app.buttons["addDrinkCategoryScrollView.coffee"].tap()
        let toggle = app.switches["addDrinkDecafToggle"]
        XCTAssertTrue(toggle.wait(for: \.isHittable, toEqual: true, timeout: 10))
        toggle.tap()
        app.steppers["addDrinkShotStepper"].buttons["addDrinkShotStepper-Increment"].tap()
        app.buttons["addDrinkSubmitButton"].tap()
        XCTAssertTrue(app.buttons["addDrinkSubmitButton"].waitForNonExistence(timeout: 10))
    }
}
