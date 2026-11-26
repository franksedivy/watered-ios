import XCTest

final class AddDrinkAlcoholUITests: XCTestCase {
    // GIVEN alcohol serving choices and a non-alcoholic cocktail draft with a previously selected strength,
    // THEN controls and draft restore correctly, and saved details retain non-alcoholic preparation with unknown exact ABV.
    @MainActor
    func testAlcoholPreparationsRestoreDraftAndSaveUnknownABV() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingInMemory", "-AppleLanguages", "(en)", "-AppleLocale", "en_GB"]
        app.launch()
        app.buttons["addDrinkActionButton"].tap()
        let categories = app.scrollViews["addDrinkCategoryScrollView"]
        let alcohol = categories.buttons["addDrinkCategoryScrollView.alcohol"]
        for _ in 0..<12 {
            if alcohol.isHittable { break }
            categories.swipeLeft()
        }
        XCTAssertTrue(alcohol.wait(for: \.isHittable, toEqual: true, timeout: 10))
        alcohol.tap()
        let types = app.scrollViews["addDrinkTypeScrollView"]
        let presets = [("beer", "330 ml", true), ("cider", "330 ml", true),
            ("wine", "175 ml", true), ("cocktail", "200 ml", true),
            ("sparkling-wine", "125 ml", true),
            ("fortified-wine", "50 ml", false), ("spirits", "25 ml", false),
            ("liqueur", "25 ml", false)]
        for (id, volume, supportsNonAlcoholic) in presets {
            let drink = types.buttons["addDrinkTypeScrollView.\(id)"]
            for _ in 0..<12 {
                if drink.isHittable { break }
                types.swipeLeft()
            }
            XCTAssertTrue(drink.wait(for: \.isHittable, toEqual: true, timeout: 10))
            drink.tap()
            XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, volume)
            XCTAssertTrue(app.sliders["addDrinkABVSlider"].exists)
            let toggle = app.switches["addDrinkNonAlcoholicToggle"]
            XCTAssertTrue(toggle.exists)
            XCTAssertEqual(toggle.isEnabled, supportsNonAlcoholic)
            XCTAssertEqual(toggle.value as? String, "0")
            XCTAssertFalse(app.steppers["addDrinkShotStepper"].exists)
            if supportsNonAlcoholic {
                XCTAssertEqual(toggle.value as? String, "0")
                toggle.tap()
                let slider = app.sliders["addDrinkABVSlider"]
                XCTAssertTrue(slider.exists)
                XCTAssertFalse(slider.isEnabled)
                XCTAssertEqual(slider.value as? String, "Up to 0.5% ABV; exact amount unknown")
                toggle.tap()
                XCTAssertTrue(slider.isEnabled)
            }
        }
        let cocktail = types.buttons["addDrinkTypeScrollView.cocktail"]
        for _ in 0..<12 {
            if cocktail.isHittable { break }
            types.swipeRight()
        }
        XCTAssertTrue(cocktail.wait(for: \.isHittable, toEqual: true, timeout: 10))
        cocktail.tap()
        app.sliders["addDrinkABVSlider"].adjust(toNormalizedSliderPosition: 1)
        XCTAssertEqual(app.sliders["addDrinkABVSlider"].value as? String, "25%")
        app.switches["addDrinkNonAlcoholicToggle"].tap()
        dismissAddDrinkSheet(in: app)
        app.buttons["addDrinkActionButton"].tap()
        XCTAssertEqual(app.switches["addDrinkNonAlcoholicToggle"].value as? String, "1")
        XCTAssertTrue(app.sliders["addDrinkABVSlider"].exists)
        XCTAssertFalse(app.sliders["addDrinkABVSlider"].isEnabled)
        XCTAssertEqual(app.sliders["addDrinkABVSlider"].value as? String, "Up to 0.5% ABV; exact amount unknown")
        app.switches["addDrinkNonAlcoholicToggle"].tap()
        XCTAssertEqual(app.sliders["addDrinkABVSlider"].value as? String, "25%")
        app.switches["addDrinkNonAlcoholicToggle"].tap()
        app.buttons["addDrinkSubmitButton"].tap()
        XCTAssertTrue(app.buttons["addDrinkSubmitButton"].waitForNonExistence(timeout: 10))
        app.tabBars.buttons["Stats"].tap()
        let row = app.collectionViews["statsDrinkHistoryList"].buttons["statsDrinkEntryLink"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        let detail = app.collectionViews["statsDrinkEntryDetailList"]
        XCTAssertTrue(detail.waitForExistence(timeout: 10))
        XCTAssertTrue(detail.staticTexts["statsHydrationContribution"].label.contains("190 ml"))
        XCTAssertTrue(detail.staticTexts["statsCaffeineAmount"].label.contains("Unknown"))
        XCTAssertTrue(detail.staticTexts["statsAlcoholABV"].label.contains("Unknown"))
        XCTAssertTrue(detail.staticTexts["statsAlcoholPreparation"].label.contains("Non-alcoholic"))
    }
}
