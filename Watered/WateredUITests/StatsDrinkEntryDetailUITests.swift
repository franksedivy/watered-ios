import XCTest

final class StatsDrinkEntryDetailUITests: XCTestCase {
    // Wait for a condition instead of assuming hosted UI transitions finish within three seconds.
    private let readinessTimeout: TimeInterval = 10

    // GIVEN a drink logged in imperial ounces, when US ounces are selected in Profile,
    // THEN history and detail convert its saved amount and contribution without changing the ratio.
    @MainActor
    func testSavedImperialDrinkReformatsInUSFluidOunces() {
        assertDisplayUnitChange(
            initialUnit: "imp fl oz",
            initialAmount: "8 fl oz",
            targetUnit: "US fl oz",
            expectedAmount: "7.686 US fl oz"
        )
    }

    // GIVEN a drink logged in imperial ounces, when millilitres are selected in Profile,
    // THEN history and detail show its converted volume while retaining the saved hydration ratio.
    @MainActor
    func testSavedImperialDrinkReformatsInMillilitres() throws {
        assertDisplayUnitChange(
            initialUnit: "imp fl oz",
            initialAmount: "8 fl oz",
            targetUnit: "ml",
            expectedAmount: "227.305 ml"
        )
    }

    // GIVEN a drink logged in millilitres, when imperial ounces are selected in Profile,
    // THEN history and detail show the converted amount and contribution with an unchanged ratio.
    @MainActor
    func testSavedMetricDrinkReformatsInImperialFluidOunces() {
        assertDisplayUnitChange(
            initialUnit: "ml",
            initialAmount: "330 ml",
            targetUnit: "imp fl oz",
            expectedAmount: "11.614 fl oz"
        )
    }

    // GIVEN regular coffee with a reviewed estimate, when its saved detail is opened,
    // THEN caffeine shows the saved estimate, the regular preparation and configured default shots are shown.
    @MainActor
    func testCoffeeShowsEstimatedCaffeineAndRegularPreparation() {
        let app = openDrinkDetail(drinkID: "latte", categoryID: "coffee")

        assertCaffeine(in: app, preparation: "Regular", shots: 2, milligrams: 120)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Stats caffeine details"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    // GIVEN decaf coffee with a reviewed estimate, when its saved detail is opened,
    // THEN the decaf preparation remains visible without claiming a zero caffeine amount.
    @MainActor
    func testDecafShowsEstimatedCaffeineAndDecafPreparation() {
        let app = openDrinkDetail(drinkID: "latte", categoryID: "coffee", decaf: true)

        assertCaffeine(in: app, preparation: "Decaf", shots: 2, milligrams: 10)
    }

    // GIVEN a drink with an explicitly zero caffeine estimate, when its detail is opened,
    // THEN no caffeine section or preparation rows are shown.
    @MainActor
    func testKnownCaffeineFreeDrinkHidesCaffeineDetails() {
        let app = openDrinkDetail(drinkID: "still-water")
        let detail = app.collectionViews["statsDrinkEntryDetailList"]

        for identifier in ["statsCaffeineAmount", "statsCaffeinePreparation", "statsCaffeineShotCount"] {
            XCTAssertFalse(detail.staticTexts[identifier].exists)
        }
    }

    // Logs the selected bundled drink in isolated storage and opens its saved Stats detail.
    @MainActor
    private func openDrinkDetail(
        drinkID: String,
        categoryID: String = "water",
        initialUnit: String = "ml",
        decaf: Bool = false
    ) -> XCUIApplication {
        let app = logDrink(drinkID: drinkID, categoryID: categoryID, initialUnit: initialUnit, decaf: decaf)
        let historyRow = savedDrinkRow(in: app)
        historyRow.tap()
        XCTAssertTrue(app.collectionViews["statsDrinkEntryDetailList"].waitForExistence(timeout: readinessTimeout))
        return app
    }

    // Submits a drink through Add Drink without navigating into its detail as part of setup.
    @MainActor
    private func logDrink(
        drinkID: String,
        categoryID: String = "water",
        initialUnit: String,
        decaf: Bool = false
    ) -> XCUIApplication {
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
        XCTAssertTrue(addButton.waitForExistence(timeout: readinessTimeout))
        XCTAssertTrue(addButton.wait(for: \.isHittable, toEqual: true, timeout: readinessTimeout))
        addButton.tap()

        let categories = app.scrollViews["addDrinkCategoryScrollView"]
        XCTAssertTrue(categories.waitForExistence(timeout: readinessTimeout))
        let category = categories.buttons["addDrinkCategoryScrollView.\(categoryID)"]
        XCTAssertTrue(category.wait(for: \.isHittable, toEqual: true, timeout: readinessTimeout))
        category.tap()
        XCTAssertTrue(category.wait(for: \.isSelected, toEqual: true, timeout: readinessTimeout))

        let types = app.scrollViews["addDrinkTypeScrollView"]
        XCTAssertTrue(types.waitForExistence(timeout: readinessTimeout))
        let selectedDrink = types.buttons["addDrinkTypeScrollView.\(drinkID)"]
        revealDrink(selectedDrink, in: types, app: app)
        selectedDrink.tap()
        XCTAssertTrue(selectedDrink.wait(for: \.isSelected, toEqual: true, timeout: readinessTimeout))

        if decaf {
            let toggle = app.switches["addDrinkDecafToggle"]
            XCTAssertTrue(toggle.wait(for: \.isHittable, toEqual: true, timeout: readinessTimeout))
            toggle.tap()
        }

        let submitButton = app.buttons["addDrinkSubmitButton"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: readinessTimeout))
        XCTAssertTrue(submitButton.wait(for: \.isHittable, toEqual: true, timeout: readinessTimeout))
        submitButton.tap()
        XCTAssertTrue(submitButton.waitForNonExistence(timeout: readinessTimeout))
        return app
    }

    // Moves half a viewport at a controlled speed and reverses if the target was passed.
    // The eager pill row exposes offscreen frames, so direction comes from the actual drink.
    @MainActor
    private func revealDrink(_ drink: XCUIElement, in row: XCUIElement, app: XCUIApplication) {
        XCTAssertTrue(drink.waitForExistence(timeout: readinessTimeout))
        XCTAssertTrue(row.wait(for: \.isHittable, toEqual: true, timeout: readinessTimeout))

        for _ in 0..<20 {
            if drink.isHittable {
                break
            }

            let targetIsToTheLeft = drink.frame.midX < row.frame.midX
            let start = row.coordinate(withNormalizedOffset: CGVector(
                dx: targetIsToTheLeft ? 0.25 : 0.75, dy: 0.5
            ))
            let end = row.coordinate(withNormalizedOffset: CGVector(
                dx: targetIsToTheLeft ? 0.75 : 0.25, dy: 0.5
            ))
            start.press(
                forDuration: 0.1,
                thenDragTo: end,
                withVelocity: .slow,
                thenHoldForDuration: 0.2
            )
        }

        let isHittable = drink.wait(for: \.isHittable, toEqual: true, timeout: readinessTimeout)
        if !isHittable {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Drink selection could not reach \(drink.identifier)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            let hierarchy = XCTAttachment(string: row.debugDescription)
            hierarchy.name = "Drink selection row"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        XCTAssertTrue(isHittable, "Could not reach drink pill \(drink.identifier)")
    }

    // Returns the single saved row from this test's isolated store after opening Stats.
    @MainActor
    private func savedDrinkRow(in app: XCUIApplication) -> XCUIElement {
        app.tabBars.buttons["Stats"].tap()
        let history = app.collectionViews["statsDrinkHistoryList"]
        XCTAssertTrue(history.waitForExistence(timeout: readinessTimeout))
        let historyRow = history.buttons["statsDrinkEntryLink"]
        XCTAssertTrue(historyRow.waitForExistence(timeout: readinessTimeout))
        XCTAssertTrue(historyRow.wait(for: \.isHittable, toEqual: true, timeout: readinessTimeout))
        return historyRow
    }

    // Exercises one conversion per test so all supported target units have independent time budgets.
    @MainActor
    private func assertDisplayUnitChange(
        initialUnit: String,
        initialAmount: String,
        targetUnit: String,
        expectedAmount: String
    ) {
        let app = logDrink(drinkID: "still-water", initialUnit: initialUnit)
        let originalRow = savedDrinkRow(in: app)
        XCTAssertTrue(originalRow.label.contains(initialAmount))

        changeDisplayUnit(to: targetUnit, in: app)
        let historyRow = savedDrinkRow(in: app)
        XCTAssertTrue(historyRow.label.contains(expectedAmount))
        historyRow.tap()
        assertDisplayedVolumes(in: app, expected: expectedAmount)
    }

    // Changes the preference through Profile without altering the logged drink.
    @MainActor
    private func changeDisplayUnit(to unitLabel: String, in app: XCUIApplication) {
        app.tabBars.buttons["Today"].tap()
        let profileButton = app.buttons["profileButton"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: readinessTimeout))
        XCTAssertTrue(profileButton.wait(for: \.isHittable, toEqual: true, timeout: readinessTimeout))
        profileButton.tap()

        let picker = app.segmentedControls["displayUnitPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: readinessTimeout))
        let unitButton = picker.buttons[unitLabel]
        XCTAssertTrue(unitButton.wait(for: \.isHittable, toEqual: true, timeout: readinessTimeout))
        unitButton.tap()
        XCTAssertTrue(unitButton.wait(for: \.isSelected, toEqual: true, timeout: readinessTimeout))
        dismissProfile(in: app)
    }

    // Uses Profile's explicit close action so setup does not depend on an interactive drag.
    @MainActor
    private func dismissProfile(in app: XCUIApplication) {
        let navigationBar = app.navigationBars["Profile"]
        let doneButton = navigationBar.buttons["profileDoneButton"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: readinessTimeout))
        XCTAssertTrue(doneButton.wait(for: \.isHittable, toEqual: true, timeout: readinessTimeout))
        doneButton.tap()

        let picker = app.segmentedControls["displayUnitPicker"]
        XCTAssertTrue(picker.waitForNonExistence(timeout: readinessTimeout))
        XCTAssertTrue(navigationBar.waitForNonExistence(timeout: readinessTimeout))
        XCTAssertTrue(app.buttons["profileButton"].wait(
            for: \.isHittable, toEqual: true, timeout: readinessTimeout
        ))
    }

    // Confirms both volume rows use the selected unit while the saved ratio stays dimensionless.
    @MainActor
    private func assertDisplayedVolumes(in app: XCUIApplication, expected: String) {
        let detail = app.collectionViews["statsDrinkEntryDetailList"]
        XCTAssertTrue(detail.waitForExistence(timeout: readinessTimeout))
        for identifier in ["statsDrinkAmount", "statsHydrationContribution"] {
            let row = detail.staticTexts[identifier]
            XCTAssertTrue(row.waitForExistence(timeout: readinessTimeout))
            XCTAssertTrue(row.label.contains(expected))
        }
        let ratio = detail.staticTexts["statsHydrationRatio"]
        XCTAssertTrue(ratio.waitForExistence(timeout: readinessTimeout))
        XCTAssertTrue(ratio.label.contains("100%"))
    }

    // Checks the captured preparation and preserves the distinction between unknown and zero.
    @MainActor
    private func assertCaffeine(in app: XCUIApplication, preparation: String, shots: Int, milligrams: Int) {
        let detail = app.collectionViews["statsDrinkEntryDetailList"]
        XCTAssertTrue(detail.waitForExistence(timeout: readinessTimeout))
        let amount = detail.staticTexts["statsCaffeineAmount"]
        let variant = detail.staticTexts["statsCaffeinePreparation"]
        XCTAssertTrue(amount.waitForExistence(timeout: readinessTimeout))
        XCTAssertTrue(amount.label.contains("\(milligrams) mg"))
        XCTAssertTrue(variant.waitForExistence(timeout: readinessTimeout))
        XCTAssertTrue(variant.label.contains(preparation))
        XCTAssertTrue(detail.staticTexts["statsCaffeineShotCount"].label.contains("\(shots)"))
    }
}
