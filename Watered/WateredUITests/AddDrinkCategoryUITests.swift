import XCTest

final class AddDrinkCategoryUITests: XCTestCase {
    private let readinessTimeout: TimeInterval = 10

    // GIVEN Add Drink has just opened, when no category has been chosen,
    // THEN no category is active, Type is hidden and form submission is disabled.
    @MainActor
    func testOpeningSheetHasNoCategorySelection() {
        let app = openAddDrink()
        let categories = app.scrollViews["addDrinkCategoryScrollView"]
        XCTAssertGreaterThan(categories.buttons.count, 0)
        for category in categories.buttons.allElementsBoundByIndex {
            XCTAssertFalse(category.isSelected)
        }
        XCTAssertFalse(app.scrollViews["addDrinkTypeScrollView"].exists)
        let submitButton = app.buttons["addDrinkSubmitButton"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: readinessTimeout))
        XCTAssertFalse(submitButton.isEnabled)
    }

    // GIVEN a selected volume, when the category changes to Coffee and back to Water,
    // THEN Type contains only that category's drinks and the volume remains unchanged.
    @MainActor
    func testChangingCategoryFiltersTypesAndPreservesVolume() {
        let app = openAddDrink()
        let volumeWheel = app.pickerWheels.firstMatch
        XCTAssertTrue(volumeWheel.waitForExistence(timeout: readinessTimeout))
        volumeWheel.adjust(toPickerWheelValue: "500 ml")

        let categories = app.scrollViews["addDrinkCategoryScrollView"]
        let coffee = categories.buttons["addDrinkCategoryScrollView.coffee"]
        XCTAssertTrue(coffee.wait(for: \.isHittable, toEqual: true, timeout: readinessTimeout))
        coffee.tap()
        XCTAssertTrue(coffee.wait(for: \.isSelected, toEqual: true, timeout: readinessTimeout))

        let types = app.scrollViews["addDrinkTypeScrollView"]
        let latte = types.buttons["addDrinkTypeScrollView.latte"]
        XCTAssertTrue(latte.wait(for: \.isSelected, toEqual: true, timeout: readinessTimeout))
        XCTAssertFalse(types.buttons["addDrinkTypeScrollView.still-water"].exists)

        let water = categories.buttons["addDrinkCategoryScrollView.water"]
        water.tap()
        XCTAssertTrue(water.wait(for: \.isSelected, toEqual: true, timeout: readinessTimeout))
        let stillWater = types.buttons["addDrinkTypeScrollView.still-water"]
        XCTAssertTrue(stillWater.wait(for: \.isSelected, toEqual: true, timeout: readinessTimeout))
        XCTAssertTrue(app.buttons["addDrinkSubmitButton"].isEnabled)
        XCTAssertFalse(types.buttons["addDrinkTypeScrollView.latte"].exists)
        XCTAssertEqual(volumeWheel.value as? String, "500 ml")
    }

    // GIVEN Sparkling water is selected, when the active Water category is tapped again,
    // THEN the chosen drink remains selected instead of reverting to the category's first drink.
    @MainActor
    func testRetappingCategoryPreservesSelectedDrink() {
        let app = openAddDrink()
        let water = app.scrollViews["addDrinkCategoryScrollView"]
            .buttons["addDrinkCategoryScrollView.water"]
        XCTAssertTrue(water.wait(for: \.isHittable, toEqual: true, timeout: readinessTimeout))
        water.tap()
        let types = app.scrollViews["addDrinkTypeScrollView"]
        let sparklingWater = types.buttons["addDrinkTypeScrollView.sparkling-water"]
        XCTAssertTrue(sparklingWater.wait(for: \.isHittable, toEqual: true, timeout: readinessTimeout))
        sparklingWater.tap()
        XCTAssertTrue(sparklingWater.wait(for: \.isSelected, toEqual: true, timeout: readinessTimeout))

        water.tap()
        XCTAssertTrue(water.isSelected)
        XCTAssertTrue(sparklingWater.isSelected)
        XCTAssertFalse(types.buttons["addDrinkTypeScrollView.still-water"].isSelected)
    }

    // Changing preparation keeps the chosen cup volume and hides unsupported controls.
    @MainActor
    func testCoffeePreparationPreservesVolume() {
        let app = openAddDrink()
        let wheel = app.pickerWheels.firstMatch
        wheel.adjust(toPickerWheelValue: "500 ml")
        app.buttons["addDrinkCategoryScrollView.coffee"].tap()
        let toggle = app.switches["addDrinkDecafToggle"]
        XCTAssertTrue(toggle.wait(for: \.isHittable, toEqual: true, timeout: readinessTimeout))
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        let shots = app.steppers["addDrinkShotStepper"]
        XCTAssertTrue(shots.waitForExistence(timeout: readinessTimeout))
        XCTAssertEqual(shots.value as? String, "2")
        shots.buttons["addDrinkShotStepper-Increment"].tap()
        XCTAssertEqual(shots.value as? String, "3")
        for expected in [2, 1, 0] {
            shots.buttons["addDrinkShotStepper-Decrement"].tap()
            XCTAssertEqual(shots.value as? String, "\(expected)")
            XCTAssertEqual(wheel.value as? String, "500 ml")
        }
        XCTAssertFalse(shots.buttons["addDrinkShotStepper-Decrement"].isEnabled)
        XCTAssertEqual(wheel.value as? String, "500 ml")
        app.buttons["addDrinkCategoryScrollView.water"].tap()
        XCTAssertFalse(toggle.exists)
        XCTAssertFalse(shots.exists)
        XCTAssertEqual(wheel.value as? String, "500 ml")
    }

    @MainActor
    func testShotBasedDrinkDefaultsAndIcedCoffeeControls() {
        let app = openAddDrink()
        app.buttons["addDrinkCategoryScrollView.coffee"].tap()
        let types = app.scrollViews["addDrinkTypeScrollView"]
        let shots = app.steppers["addDrinkShotStepper"]
        for (id, count) in [("latte", 2), ("cappuccino", 1), ("iced-coffee", 2), ("espresso", 1), ("americano", 2)] {
            let drink = types.buttons["addDrinkTypeScrollView.\(id)"]
            for _ in 0..<6 where !drink.isHittable { types.swipeLeft() }
            XCTAssertTrue(drink.wait(for: \.isHittable, toEqual: true, timeout: readinessTimeout))
            drink.tap()
            XCTAssertTrue(shots.waitForExistence(timeout: readinessTimeout))
            XCTAssertEqual(shots.value as? String, "\(count)")
            if id == "iced-coffee" {
                shots.buttons["addDrinkShotStepper-Increment"].tap()
                XCTAssertEqual(shots.value as? String, "3")
                let screenshot = XCTAttachment(screenshot: app.screenshot())
                screenshot.name = "Iced coffee shot selection"
                screenshot.lifetime = .keepAlways
                add(screenshot)
            }
        }
    }

    // Dismissing retains the unsaved preparation; successfully saving clears it.
    @MainActor
    func testDismissedDraftRestoresAndSuccessfulSaveClearsIt() {
        let app = openAddDrink()
        app.buttons["addDrinkCategoryScrollView.coffee"].tap()
        let toggle = app.switches["addDrinkDecafToggle"]
        XCTAssertTrue(toggle.wait(for: \.isHittable, toEqual: true, timeout: readinessTimeout))
        toggle.tap()
        let shots = app.steppers["addDrinkShotStepper"]
        shots.buttons["addDrinkShotStepper-Increment"].tap()
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "500 ml")

        let submit = app.buttons["addDrinkSubmitButton"]
        dismissAddDrinkSheet(in: app)
        XCTAssertTrue(submit.waitForNonExistence(timeout: readinessTimeout))
        app.buttons["addDrinkActionButton"].tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: readinessTimeout))
        XCTAssertEqual(toggle.value as? String, "1")
        XCTAssertEqual(shots.value as? String, "3")
        XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, "500 ml")
        XCTAssertTrue(app.buttons["addDrinkTypeScrollView.latte"].isSelected)

        submit.tap()
        XCTAssertTrue(submit.waitForNonExistence(timeout: readinessTimeout))
        app.buttons["addDrinkActionButton"].tap()
        XCTAssertTrue(submit.waitForExistence(timeout: readinessTimeout))
        XCTAssertFalse(submit.isEnabled)
        XCTAssertFalse(app.scrollViews["addDrinkTypeScrollView"].exists)
        XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, "330 ml")
    }

    @MainActor
    func testAppRestartDiscardsUnsavedDraft() {
        let app = openAddDrink()
        app.buttons["addDrinkCategoryScrollView.coffee"].tap()
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "500 ml")
        app.terminate()
        app.launch()
        let add = app.buttons["addDrinkActionButton"]
        XCTAssertTrue(add.wait(for: \.isHittable, toEqual: true, timeout: readinessTimeout))
        add.tap()
        let submit = app.buttons["addDrinkSubmitButton"]
        XCTAssertTrue(submit.waitForExistence(timeout: readinessTimeout))
        XCTAssertFalse(submit.isEnabled)
        XCTAssertFalse(app.scrollViews["addDrinkTypeScrollView"].exists)
        XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, "330 ml")
    }

    @MainActor
    func testProfileUnitChangeConvertsDraftAndPreservesSavedVolumeAndPreparation() {
        let app = openAddDrink()
        app.buttons["addDrinkCategoryScrollView.coffee"].tap()
        let toggle = app.switches["addDrinkDecafToggle"]
        XCTAssertTrue(toggle.wait(for: \.isHittable, toEqual: true, timeout: readinessTimeout))
        toggle.tap()
        let shots = app.steppers["addDrinkShotStepper"]
        shots.buttons["addDrinkShotStepper-Increment"].tap()
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "500 ml")
        dismissAddDrinkSheet(in: app)
        changeAddDrinkDisplayUnit(to: "US fl oz", in: app)
        app.buttons["addDrinkActionButton"].tap()
        let submit = app.buttons["addDrinkSubmitButton"]
        XCTAssertTrue(submit.waitForExistence(timeout: readinessTimeout))
        XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, "16.907 US fl oz")
        XCTAssertEqual(toggle.value as? String, "1")
        XCTAssertEqual(shots.value as? String, "3")
        XCTAssertTrue(app.buttons["addDrinkTypeScrollView.latte"].isSelected)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Converted draft retains 500 ml and coffee preparation"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        submit.tap()
        XCTAssertTrue(submit.waitForNonExistence(timeout: readinessTimeout))
        app.buttons["addDrinkActionButton"].tap()
        XCTAssertTrue(submit.waitForExistence(timeout: readinessTimeout))
        XCTAssertFalse(submit.isEnabled)
        XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, "12 US fl oz")
        dismissAddDrinkSheet(in: app)
        changeAddDrinkDisplayUnit(to: "ml", in: app)
        XCTAssertTrue(app.staticTexts["todayTotalAmountText"].wait(
            for: \.label, toEqual: "500 ml", timeout: readinessTimeout
        ))
        app.tabBars.buttons["Stats"].tap()
        let row = app.collectionViews["statsDrinkHistoryList"].buttons["statsDrinkEntryLink"]
        XCTAssertTrue(row.waitForExistence(timeout: readinessTimeout))
        row.tap()
        let detail = app.collectionViews["statsDrinkEntryDetailList"]
        XCTAssertTrue(detail.waitForExistence(timeout: readinessTimeout))
        XCTAssertTrue(detail.staticTexts["statsDrinkAmount"].label.contains("500 ml"))
        XCTAssertTrue(detail.staticTexts["statsCaffeinePreparation"].label.contains("Decaf"))
        XCTAssertTrue(detail.staticTexts["statsCaffeineShotCount"].label.contains("3"))
    }

    @MainActor
    func testFreshFormUsesEachAppliedProfileUnit() {
        let app = openAddDrink()
        dismissAddDrinkSheet(in: app)
        for (unit, expected) in [("US fl oz", "12 US fl oz"), ("imp fl oz", "8 fl oz"), ("ml", "330 ml")] {
            changeAddDrinkDisplayUnit(to: unit, in: app)
            app.buttons["addDrinkActionButton"].tap()
            let wheel = app.pickerWheels.firstMatch
            XCTAssertTrue(wheel.waitForExistence(timeout: readinessTimeout))
            XCTAssertEqual(wheel.value as? String, expected)
            XCTAssertFalse(app.buttons["addDrinkSubmitButton"].isEnabled)
            dismissAddDrinkSheet(in: app)
        }
    }

    @MainActor
    func testSelectingPresetAfterConversionChangesPhysicalAmount() {
        let app = openAddDrink()
        app.buttons["addDrinkCategoryScrollView.water"].tap()
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "500 ml")
        dismissAddDrinkSheet(in: app)
        changeAddDrinkDisplayUnit(to: "US fl oz", in: app)
        app.buttons["addDrinkActionButton"].tap()
        let wheel = app.pickerWheels.firstMatch
        XCTAssertTrue(wheel.waitForExistence(timeout: readinessTimeout))
        XCTAssertEqual(wheel.value as? String, "16.907 US fl oz")
        wheel.adjust(toPickerWheelValue: "16 US fl oz")
        app.buttons["addDrinkSubmitButton"].tap()
        XCTAssertTrue(app.buttons["addDrinkSubmitButton"].waitForNonExistence(timeout: readinessTimeout))
        changeAddDrinkDisplayUnit(to: "ml", in: app)
        app.tabBars.buttons["Stats"].tap()
        let row = app.collectionViews["statsDrinkHistoryList"].buttons["statsDrinkEntryLink"]
        XCTAssertTrue(row.waitForExistence(timeout: readinessTimeout))
        XCTAssertTrue(row.label.contains("473.176 ml"))
    }

    @MainActor
    func testTeaDefaultsDecafAndSavedEstimates() {
        let app = openAddDrink()
        let tea = app.buttons["addDrinkCategoryScrollView.tea"]
        XCTAssertTrue(tea.wait(for: \.isHittable, toEqual: true, timeout: readinessTimeout))
        tea.tap()
        let wheel = app.pickerWheels.firstMatch
        XCTAssertEqual(wheel.value as? String, "250 ml")
        XCTAssertTrue(app.buttons["addDrinkTypeScrollView.black-tea"].isSelected)
        let toggle = app.switches["addDrinkDecafToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: readinessTimeout))
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertFalse(app.steppers["addDrinkShotStepper"].exists)
        toggle.tap()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Plain tea with decaf and 250 ml default"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["addDrinkSubmitButton"].tap()
        XCTAssertTrue(app.buttons["addDrinkSubmitButton"].waitForNonExistence(timeout: readinessTimeout))
        app.tabBars.buttons["Stats"].tap()
        let row = app.collectionViews["statsDrinkHistoryList"].buttons["statsDrinkEntryLink"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: readinessTimeout))
        row.tap()
        let detail = app.collectionViews["statsDrinkEntryDetailList"]
        XCTAssertTrue(detail.waitForExistence(timeout: readinessTimeout))
        XCTAssertTrue(detail.staticTexts["statsCaffeineAmount"].label.contains("5 mg"))
        XCTAssertTrue(detail.staticTexts["statsHydrationContribution"].label.contains("247.5 ml"))
        XCTAssertTrue(detail.staticTexts["statsCaffeinePreparation"].label.contains("Decaf"))
    }

    @MainActor
    func testTeaTypesPreserveChosenVolumeAndHerbalHidesDecaf() {
        let app = openAddDrink()
        let wheel = app.pickerWheels.firstMatch
        wheel.adjust(toPickerWheelValue: "500 ml")
        app.buttons["addDrinkCategoryScrollView.tea"].tap()
        let types = app.scrollViews["addDrinkTypeScrollView"]
        let toggle = app.switches["addDrinkDecafToggle"]
        for id in ["black-tea", "green-tea", "white-tea", "herbal-tea"] {
            let drink = types.buttons["addDrinkTypeScrollView.\(id)"]
            for _ in 0..<4 where !drink.isHittable { types.swipeLeft() }
            XCTAssertTrue(drink.wait(for: \.isHittable, toEqual: true, timeout: readinessTimeout))
            drink.tap()
            XCTAssertEqual(wheel.value as? String, "500 ml")
            XCTAssertFalse(app.steppers["addDrinkShotStepper"].exists)
            if id == "herbal-tea" {
                XCTAssertFalse(toggle.exists)
            } else {
                XCTAssertTrue(toggle.waitForExistence(timeout: readinessTimeout))
                XCTAssertEqual(toggle.value as? String, "0")
                toggle.tap()
            }
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Herbal tea without caffeine controls"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testRemainingTeasDefaultsAndCaffeineFreeOptions() {
        let app = openAddDrink()
        app.buttons["addDrinkCategoryScrollView.tea"].tap()
        let types = app.scrollViews["addDrinkTypeScrollView"]
        let toggle = app.switches["addDrinkCaffeineFreeToggle"]
        for id in ["matcha", "matcha-latte", "bubble-milk-tea", "bubble-fruit-tea", "yerba-mate", "iced-tea"] {
            let drink = types.buttons["addDrinkTypeScrollView.\(id)"]
            for _ in 0..<10 where !drink.isHittable { types.swipeLeft() }
            XCTAssertTrue(drink.wait(for: \.isHittable, toEqual: true, timeout: readinessTimeout))
            drink.tap()
            XCTAssertTrue(drink.wait(for: \.isSelected, toEqual: true, timeout: readinessTimeout))
            XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, id == "iced-tea" ? "330 ml" : "250 ml")
            XCTAssertFalse(app.switches["addDrinkDecafToggle"].exists)
            XCTAssertFalse(app.steppers["addDrinkShotStepper"].exists)
            if id == "bubble-fruit-tea" || id == "iced-tea" {
                XCTAssertTrue(toggle.wait(for: \.isHittable, toEqual: true, timeout: readinessTimeout))
                XCTAssertEqual(toggle.value as? String, "0")
                XCTAssertTrue(toggle.label.contains("Caffeine-free"))
                toggle.tap()
                XCTAssertEqual(toggle.value as? String, "1")
            } else {
                XCTAssertFalse(toggle.exists)
            }
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Iced tea with caffeine-free option and 330 ml default"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "500 ml")
        dismissAddDrinkSheet(in: app)
        app.buttons["addDrinkActionButton"].tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: readinessTimeout))
        XCTAssertEqual(toggle.value as? String, "1")
        XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, "500 ml")
        app.buttons["addDrinkSubmitButton"].tap()
        XCTAssertTrue(app.buttons["addDrinkSubmitButton"].waitForNonExistence(timeout: readinessTimeout))
        app.tabBars.buttons["Stats"].tap()
        let row = app.collectionViews["statsDrinkHistoryList"].buttons["statsDrinkEntryLink"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: readinessTimeout))
        row.tap()
        let detail = app.collectionViews["statsDrinkEntryDetailList"]
        XCTAssertTrue(detail.waitForExistence(timeout: readinessTimeout))
        XCTAssertTrue(detail.staticTexts["statsDrinkAmount"].label.contains("500 ml"))
        XCTAssertTrue(detail.staticTexts["statsHydrationContribution"].label.contains("475 ml"))
        // Keep the existing detail contract: explicitly zero caffeine hides this section.
        XCTAssertFalse(detail.staticTexts["statsCaffeineAmount"].exists)
    }

    // Opens the sheet with an empty store and predictable units for category interaction checks.
    @MainActor
    private func openAddDrink() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestingInMemory",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_GB"
        ]
        app.launch()

        let addButton = app.buttons["addDrinkActionButton"]
        XCTAssertTrue(addButton.wait(for: \.isHittable, toEqual: true, timeout: readinessTimeout))
        addButton.tap()
        XCTAssertTrue(
            app.scrollViews["addDrinkCategoryScrollView"].waitForExistence(timeout: readinessTimeout)
        )
        return app
    }
}

// Drag the native grabber beyond the sheet, rather than swiping inside its toolbar.
extension XCTestCase {
    @MainActor
    func dismissAddDrinkSheet(in app: XCUIApplication) {
        let submit = app.buttons["addDrinkSubmitButton"]
        for _ in 0..<3 {
            let grabber = app.buttons["Sheet Grabber"]
            XCTAssertTrue(grabber.waitForExistence(timeout: 5))
            grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.1, thenDragTo:
                    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
            if submit.waitForNonExistence(timeout: 2) { return }
        }
        XCTFail("Dragging the sheet grabber should dismiss Add drink.")
    }
}

extension XCTestCase {
    @MainActor
    func changeAddDrinkDisplayUnit(to unit: String, in app: XCUIApplication, fails: Bool = false) {
        let profile = app.buttons["profileButton"]
        XCTAssertTrue(profile.wait(for: \.isHittable, toEqual: true, timeout: 10))
        profile.tap()
        let picker = app.segmentedControls["displayUnitPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        picker.buttons[unit].tap()
        if fails {
            let alert = app.alerts["Could not save your display unit"]
            XCTAssertTrue(alert.waitForExistence(timeout: 10))
            alert.buttons["OK"].tap()
            XCTAssertTrue(picker.buttons["ml"].wait(for: \.isSelected, toEqual: true, timeout: 10))
        } else {
            XCTAssertTrue(picker.buttons[unit].wait(for: \.isSelected, toEqual: true, timeout: 10))
        }
        app.buttons["profileDoneButton"].tap()
        XCTAssertTrue(picker.waitForNonExistence(timeout: 10))
    }
}
