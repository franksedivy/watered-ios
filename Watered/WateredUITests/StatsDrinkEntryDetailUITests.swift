import XCTest

final class StatsDrinkEntryDetailUITests: XCTestCase {
    // GIVEN a drink logged in imperial ounces, when the app's display unit changes,
    // THEN its reopened detail converts Amount and Contribution without changing their ratio.
    @MainActor
    func testDisplayUnitChangesReformatSavedDrinkVolumes() {
        let app = openDrinkDetail(drinkID: "still-water", initialUnit: "imp fl oz")
        assertDisplayedVolumes(in: app, expected: "8 fl oz")

        let selections = [
            ("US fl oz", "7.686 US fl oz"),
            ("ml", "227.305 ml"),
            ("imp fl oz", "8 fl oz")
        ]
        for (unitLabel, expectedVolume) in selections {
            app.navigationBars.buttons.firstMatch.tap()
            changeDisplayUnit(to: unitLabel, in: app)
            app.tabBars.buttons["Stats"].tap()

            let historyRow = app.buttons.matching(identifier: "statsDrinkEntryLink").firstMatch
            XCTAssertTrue(historyRow.waitForExistence(timeout: 3))
            XCTAssertTrue(historyRow.label.contains(expectedVolume))
            historyRow.tap()
            assertDisplayedVolumes(in: app, expected: expectedVolume)
        }
    }

    // GIVEN regular coffee with an unknown estimate, when its saved detail is opened,
    // THEN caffeine remains unknown, the regular preparation is shown and no shots are invented.
    @MainActor
    func testCoffeeShowsUnknownCaffeineAndRegularPreparation() {
        let app = openDrinkDetail(drinkID: "latte")

        assertUnknownCaffeine(in: app, preparation: "Regular")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Stats caffeine details"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    // GIVEN decaf coffee with an unknown estimate, when its saved detail is opened,
    // THEN the decaf preparation remains visible without claiming a zero caffeine amount.
    @MainActor
    func testDecafShowsUnknownCaffeineAndDecafPreparation() {
        let app = openDrinkDetail(drinkID: "decaf-coffee")

        assertUnknownCaffeine(in: app, preparation: "Decaf")
    }

    // GIVEN a drink with an explicitly zero caffeine estimate, when its detail is opened,
    // THEN no caffeine section or preparation rows are shown.
    @MainActor
    func testKnownCaffeineFreeDrinkHidesCaffeineDetails() {
        let app = openDrinkDetail(drinkID: "still-water")

        for identifier in ["statsCaffeineAmount", "statsCaffeinePreparation", "statsCaffeineShotCount"] {
            XCTAssertFalse(app.descendants(matching: .any).matching(identifier: identifier).firstMatch.exists)
        }
    }

    // Logs the selected bundled drink in isolated storage and opens its saved Stats detail.
    @MainActor
    private func openDrinkDetail(drinkID: String, initialUnit: String = "ml") -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestingInMemory",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_GB"
        ]
        app.launch()

        if initialUnit != "ml" {
            changeDisplayUnit(to: initialUnit, in: app)
        }

        let addButton = app.buttons["addDrinkActionButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        XCTAssertTrue(addButton.wait(for: \.isHittable, toEqual: true, timeout: 3))
        addButton.tap()

        let types = app.scrollViews["addDrinkTypeScrollView"]
        XCTAssertTrue(types.waitForExistence(timeout: 3))
        let selectedDrink = types.buttons["addDrinkTypeScrollView.\(drinkID)"]
        for _ in 0..<8 {
            if selectedDrink.exists && selectedDrink.isHittable {
                break
            }
            types.swipeLeft()
        }
        XCTAssertTrue(selectedDrink.exists && selectedDrink.isHittable)
        selectedDrink.tap()
        XCTAssertTrue(selectedDrink.wait(for: \.isSelected, toEqual: true, timeout: 3))

        let submitButton = app.buttons["addDrinkSubmitButton"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 3))
        submitButton.tap()
        XCTAssertTrue(submitButton.waitForNonExistence(timeout: 3))

        app.tabBars.buttons["Stats"].tap()
        let historyRow = app.buttons.matching(identifier: "statsDrinkEntryLink").firstMatch
        XCTAssertTrue(historyRow.waitForExistence(timeout: 3))
        historyRow.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(identifier: "statsDrinkEntryDetailList").firstMatch.waitForExistence(timeout: 3)
        )
        return app
    }

    // Changes the preference through Profile without altering the logged drink.
    @MainActor
    private func changeDisplayUnit(to unitLabel: String, in app: XCUIApplication) {
        app.tabBars.buttons["Today"].tap()
        let profileButton = app.buttons["profileButton"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 3))
        profileButton.tap()

        let picker = app.segmentedControls["displayUnitPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3))
        let unitButton = picker.buttons[unitLabel]
        unitButton.tap()
        XCTAssertTrue(unitButton.wait(for: \.isSelected, toEqual: true, timeout: 3))
        app.navigationBars["Profile"].swipeDown()
        XCTAssertTrue(picker.waitForNonExistence(timeout: 3))
    }

    // Confirms both volume rows use the selected unit while the saved ratio stays dimensionless.
    @MainActor
    private func assertDisplayedVolumes(in app: XCUIApplication, expected: String) {
        for identifier in ["statsDrinkAmount", "statsHydrationContribution"] {
            let row = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 3))
            XCTAssertTrue(row.label.contains(expected))
        }
        let ratio = app.descendants(matching: .any)
            .matching(identifier: "statsHydrationRatio").firstMatch
        XCTAssertTrue(ratio.waitForExistence(timeout: 3))
        XCTAssertTrue(ratio.label.contains("100%"))
    }

    // Checks the captured preparation and preserves the distinction between unknown and zero.
    @MainActor
    private func assertUnknownCaffeine(in app: XCUIApplication, preparation: String) {
        let amount = app.descendants(matching: .any)
            .matching(identifier: "statsCaffeineAmount").firstMatch
        let variant = app.descendants(matching: .any)
            .matching(identifier: "statsCaffeinePreparation").firstMatch
        XCTAssertTrue(amount.waitForExistence(timeout: 3))
        XCTAssertTrue(amount.label.contains("Unknown"))
        XCTAssertTrue(variant.waitForExistence(timeout: 3))
        XCTAssertTrue(variant.label.contains(preparation))
        XCTAssertFalse(
            app.descendants(matching: .any)
                .matching(identifier: "statsCaffeineShotCount").firstMatch.exists
        )
    }
}
