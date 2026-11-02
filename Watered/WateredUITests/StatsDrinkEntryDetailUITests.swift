import XCTest

final class StatsDrinkEntryDetailUITests: XCTestCase {
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
    private func openDrinkDetail(drinkID: String) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestingInMemory",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_GB"
        ]
        app.launch()

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
