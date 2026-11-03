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
