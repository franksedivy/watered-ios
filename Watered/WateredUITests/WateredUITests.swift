//
//  WateredUITests.swift
//  WateredUITests
//
//  Created by Frank Sedivy on 26/06/2026.
//

import XCTest

final class WateredUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    // MARK: - Test Helpers
    //
    // Purpose:
    // Launches the app with predictable starting conditions for UI flow tests.
    //
    // Returns:
    // The launched applicaiton, ready for the test to interact with.
    //
    // Behavior:
    // Uses an empty in-memory store and an English/UK locale so previous
    // drinks and settings cannot affect tests that expect millilitre values.
    @MainActor
    private func launchIsolatedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestingInMemory",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_GB"
        ]
        app.launch()
        return app
    }

    // Chooses Water explicitly so form-submission tests do not rely on a starting category.
    @MainActor
    private func selectWaterCategory(in app: XCUIApplication) {
        let water = app.scrollViews["addDrinkCategoryScrollView"]
            .buttons["addDrinkCategoryScrollView.water"]
        XCTAssertTrue(water.wait(for: \.isHittable, toEqual: true, timeout: 10))
        water.tap()
        XCTAssertTrue(water.wait(for: \.isSelected, toEqual: true, timeout: 10))
    }

    // Reveals a detail row through bounded scrolling as the inspection data grows.
    @MainActor
    private func revealDrinkDetailElement(_ element: XCUIElement, in app: XCUIApplication) {
        let list = app.descendants(matching: .any)
            .matching(identifier: "statsDrinkEntryDetailList").firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 3))
        for _ in 0..<6 {
            if element.exists && element.isHittable {
                return
            }
            list.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable)
    }

    @MainActor
    func testAppLaunchesToTodayScreen() throws {
        // Purpose: Proves that Watered launches into the main Today sexperience
        //
        // Behavior:
        // This is intentionally a smoke test. It does not check layout, color,
        // typography, or exact copy. It only checks for the stable Today screen
        // accessibility identifier.
        let app = launchIsolatedApp()
        
        let todayScreen = app.otherElements["todayScreen"]
        XCTAssertTrue(todayScreen.waitForExistence(timeout: 2))
    }
    
    @MainActor
    func testAddDrinkActionButtonExists() throws {
        // Purpose:
        // Proves that the Today screen exposes the add-drink action.
        //
        // Behavior:
        // This test only checks for the stable accessibility identifier on the
        // floating add-drink button. It does not care where the button sits visually.
        let app = launchIsolatedApp()
        
        let addDrinkButton = app.buttons["addDrinkActionButton"]
        XCTAssertTrue(addDrinkButton.waitForExistence(timeout: 2))
    }
    
    @MainActor
    func testTappingAddDrinkActionShowsAddDrinkSheet() throws {
        // Purpose:
        // Proves that the floating add-drink action opens the temporary Add Drink flow.
        //
        // Behvaior:
        // This test checks the navigation from Today into the sheet. It does not add a
        // drink yet, so failure are easier to understand if sheet presentation breaks.
        let app = launchIsolatedApp()
        
        let addDrinkButton = app.buttons["addDrinkActionButton"]
        XCTAssertTrue(addDrinkButton.waitForExistence(timeout: 2))
        
        addDrinkButton.tap()
        
        let addDrinkSubmitButton = app.buttons["addDrinkSubmitButton"]
        XCTAssertTrue(addDrinkSubmitButton.waitForExistence(timeout: 2))
    }
    
    @MainActor
    func testAddingDrinkUpdatesTodayTotalAmount() throws {
        // Purpose:
        // Proves that adding a drink updates the Today summary.
        //
        // Behvaior:
        // This test does not yet assert an exact amount.
        // It only checks that the total amount text changes away from the empty
        // starting value after a drink is added.
        let app = launchIsolatedApp()
        
        let addDrinkButton = app.buttons["addDrinkActionButton"]
        XCTAssertTrue(addDrinkButton.waitForExistence(timeout: 2))
        
        addDrinkButton.tap()
        selectWaterCategory(in: app)
        
        let addDrinkSubmitButton = app.buttons["addDrinkSubmitButton"]
        XCTAssertTrue(addDrinkSubmitButton.waitForExistence(timeout: 2))
        
        addDrinkSubmitButton.tap()
        
        let updatedTotalAmount = app.staticTexts["330 ml"]
        XCTAssertTrue(
            updatedTotalAmount.waitForExistence(timeout: 2),
            "Today should show the default Add Drink form submission as 330 ml"
        )
    }
    
    @MainActor
    func testAddingDrinkWithSelectedVolumeUpdatesTodayTotalAmount() throws {
        // Purpose:
        // Proves that the Add Drink form uses the selected volume, not only the
        // default form value.
        //
        // Behavior:
        // Opens Add Drink, adjusts the volume wheel from its default value to
        // 500 ml, submits the drink, and checks that Today shows the selected
        // amount
        let app = launchIsolatedApp()
        
        let addDrinkButton = app.buttons["addDrinkActionButton"]
        XCTAssertTrue(addDrinkButton.waitForExistence(timeout: 2))
        
        addDrinkButton.tap()
        selectWaterCategory(in: app)
        
        let volumePickerWheel = app.pickerWheels.firstMatch
        XCTAssertTrue(volumePickerWheel.waitForExistence(timeout: 2))
        
        volumePickerWheel.adjust(toPickerWheelValue: "500 ml")
        
        let addDrinkSubmitButton = app.buttons["addDrinkSubmitButton"]
        XCTAssertTrue(addDrinkSubmitButton.waitForExistence(timeout: 2))
        
        addDrinkSubmitButton.tap()
        
        let updatedTotalAmount = app.staticTexts["500 ml"]
        XCTAssertTrue(
            updatedTotalAmount.waitForExistence(timeout: 2),
            "Today should show the manually selected Add Drink volume as 500 ml"
        )
    }
    
    @MainActor
    func testAddingMultipleDrinksKeepsTodayUsable() throws {
        // Purpose: Proves that repeated drink additions do not break the Today flow
        //
        // Behvaior:
        // Each add goes through the same user path: open the sheet, tap the temporary
        // add button, return to Today. The test does not care which random drinks are
        // selected or waht exact totals are shown.
        let app = launchIsolatedApp()
        
        for addDrinkAttempt in 1...3 {
            let addDrinkButton = app.buttons["addDrinkActionButton"]
            XCTAssertTrue(addDrinkButton.waitForExistence(timeout: 2))
            
            addDrinkButton.tap()
            selectWaterCategory(in: app)
            
            let addDrinkSubmitButton = app.buttons["addDrinkSubmitButton"]
            XCTAssertTrue(addDrinkSubmitButton.waitForExistence(timeout: 2))
            
            addDrinkSubmitButton.tap()
            
            let totalAmountText = app.staticTexts["todayTotalAmountText"]
            XCTAssertTrue(
                totalAmountText.waitForExistence(timeout: 2),
                "Total amount should exist after add attempt \(addDrinkAttempt)"
            )
        }
    }
    
    // Given an empty history, when a drink is logged and its recent shortcut
    // is tapped in the long-press menu, then another drink is added without opening the sheet.
    @MainActor
    func testAddingRecentDrinkUpdatesTodayTotalAmount() throws {
        let app = launchIsolatedApp()
        
        let addDrinkButton = app.buttons["addDrinkActionButton"]
        XCTAssertTrue(addDrinkButton.waitForExistence(timeout: 3))
        addDrinkButton.tap()
        selectWaterCategory(in: app)
        
        let submitButton = app.buttons["addDrinkSubmitButton"]
        XCTAssertTrue(submitButton.waitForExistence(timeout:3))
        
        let recentDrinksRow = app.scrollViews["addDrinkRecentsScrollView"]
        XCTAssertFalse(
            recentDrinksRow.exists,
            "Recents should be hidden before any drinks are logged"
        )
        
        // Create the history that the recent-drink shortcut will use.
        submitButton.tap()
        XCTAssertTrue(submitButton.waitForNonExistence(timeout: 3))
        
        let totalAmountText = app.staticTexts["todayTotalAmountText"]
        XCTAssertTrue(totalAmountText.waitForExistence(timeout: 3))
        XCTAssertTrue(
            totalAmountText.wait(for: \.label, toEqual: "330 ml", timeout: 3),
            "The first drink should bring today's total to 330 ml"
        )
        
        addDrinkButton.press(forDuration: 1)
        let recent = app.buttons["recentDrink.still-water"]
        XCTAssertTrue(recent.waitForExistence(timeout: 5))
        recent.tap()
        XCTAssertFalse(submitButton.exists, "Repeating from the menu should not open the form")
        XCTAssertTrue(
            totalAmountText.wait(for: \.label, toEqual: "660 ml", timeout: 3),
            "Repeating the 330 ml drink should bring today's total to 660 ml"
        )
    }
    
    // GIVEN a catalogue drink selected by ID, when it is submitted and opened in Stats,
    // THEN the sheet closes and the captured catalogue name appears in its saved detail.
    @MainActor
    func testSelectingCatalogueDrinkStoresItsName() throws {
        let app = launchIsolatedApp()
        let addButton = app.buttons["addDrinkActionButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        XCTAssertTrue(addButton.wait(for: \.isHittable, toEqual: true, timeout: 3))
        addButton.tap()
        selectWaterCategory(in: app)

        let sparklingWater = app.buttons["addDrinkTypeScrollView.sparkling-water"]
        XCTAssertTrue(sparklingWater.waitForExistence(timeout: 3))
        XCTAssertTrue(sparklingWater.wait(for: \.isHittable, toEqual: true, timeout: 3))
        sparklingWater.tap()
        XCTAssertTrue(
            sparklingWater.wait(for: \.isSelected, toEqual: true, timeout: 3),
            app.debugDescription
        )

        let submitButton = app.buttons["addDrinkSubmitButton"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 3))
        submitButton.tap()
        XCTAssertTrue(submitButton.waitForNonExistence(timeout: 3))

        app.tabBars.buttons["Stats"].tap()
        let historyRow = app.buttons.matching(identifier: "statsDrinkEntryLink").firstMatch
        XCTAssertTrue(historyRow.waitForExistence(timeout: 3))
        historyRow.tap()
        XCTAssertTrue(app.navigationBars["Sparkling water"].waitForExistence(timeout: 3))

        let ratio = app.descendants(matching: .any)
            .matching(identifier: "statsHydrationRatio").firstMatch
        revealDrinkDetailElement(ratio, in: app)
        XCTAssertTrue(ratio.label.contains("100%"))

        let schema = app.descendants(matching: .any)
            .matching(identifier: "statsCatalogueSchemaVersion").firstMatch
        revealDrinkDetailElement(schema, in: app)
        XCTAssertFalse(schema.label.contains("Not recorded"))
    }

    // Given two identical dirnks, when one is deleted from Stats,
    // then its detail screen closes, one history entry remains,
    // and Today shows only the remaining drink's volume.
    @MainActor
    func testDeletingOneOfTwoIndeticalDrinksKeepsTheOther() throws {
        let app = launchIsolatedApp()
        let addDrinkButton = app.buttons["addDrinkActionButton"]
        let submitButton = app.buttons["addDrinkSubmitButton"]
        
        // Submit the default 330ml drink twice.
        for count in 1...2 {
            XCTAssertTrue(addDrinkButton.waitForExistence(timeout: 3))
            XCTAssertTrue(addDrinkButton.wait(for: \.isHittable, toEqual: true, timeout: 3))
            addDrinkButton.tap()
            selectWaterCategory(in: app)
            
            XCTAssertTrue(submitButton.waitForExistence(timeout: 3))
            submitButton.tap()
            XCTAssertTrue(submitButton.waitForNonExistence(timeout: 3))
            let totalAmount = app.staticTexts["todayTotalAmountText"]
            XCTAssertTrue(totalAmount.waitForExistence(timeout: 3))
            XCTAssertTrue(totalAmount.wait(for: \.label, toEqual: "\(count * 330) ml", timeout: 3))
        }
        
        let totalAmountText = app.staticTexts["todayTotalAmountText"]
        XCTAssertTrue(
            totalAmountText.wait(for: \.label, toEqual: "660 ml", timeout: 3)
        )
        
        let statsTab = app.tabBars.buttons["Stats"]
        XCTAssertTrue(statsTab.waitForExistence(timeout: 3))
        statsTab.tap()
        
        let historyRows = app.buttons.matching(identifier: "statsDrinkEntryLink")
        XCTAssertTrue(statsTab.waitForExistence(timeout: 3))
        XCTAssertEqual(historyRows.count, 2)
        historyRows.element(boundBy: 0).tap()

        let deleteButton = app.buttons["deleteDrinkButton"]
        revealDrinkDetailElement(deleteButton, in: app)
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3))
        deleteButton.tap()
        
        let confirmationDialog = app.sheets["Delete this drink?"]
        XCTAssertTrue(confirmationDialog.waitForExistence(timeout: 3))
        
        // The confirmation action exposes nested buttons with the same identifier.
        // Select the inner button rather than its accessibility wrapper.
        let confirmButton = confirmationDialog.buttons
            .matching(identifier: "confirmDeleteDrinkButton")
            .children(matching: .button)
            .element
        
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3))
        confirmButton.tap()
        
        // Successful deletion should return to the list with one entry.
        XCTAssertTrue(deleteButton.waitForNonExistence(timeout: 3))
        XCTAssertTrue(historyRows.element(boundBy: 0).waitForExistence(timeout: 3))
        XCTAssertTrue(historyRows.element(boundBy: 1).waitForNonExistence(timeout: 3))
        XCTAssertEqual(historyRows.count, 1)
        
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(
            totalAmountText.wait(for: \.label, toEqual: "330 ml", timeout: 3)
        )
    }
    
    // Given a saved drink, when deletion is cancelled from its detail screen,
    // then the detail remains open and Today's total stays unchanged.
    @MainActor
    func testCancellingDrinkDeletionKeepsTheDrink() throws {
        let app = launchIsolatedApp()
        
        let addDrinkButton = app.buttons["addDrinkActionButton"]
        XCTAssertTrue(addDrinkButton.waitForExistence(timeout: 3))
        addDrinkButton.tap()
        selectWaterCategory(in: app)
        
        let submitButton = app.buttons["addDrinkSubmitButton"]
        XCTAssertTrue(submitButton.waitForExistence(timeout:3))
        submitButton.tap()
        XCTAssertTrue(submitButton.waitForNonExistence(timeout: 3))
        
        let totalAmountText = app.staticTexts["todayTotalAmountText"]
        XCTAssertTrue(
            totalAmountText.wait(for: \.label, toEqual: "330 ml", timeout: 3)
        )
        
        app.tabBars.buttons["Stats"].tap()
        
        let historyRow = app.buttons
            .matching(identifier: "statsDrinkEntryLink")
            .element
        XCTAssertTrue(historyRow.waitForExistence(timeout: 3))
        historyRow.tap()
        
        let deleteButton = app.buttons["deleteDrinkButton"]
        revealDrinkDetailElement(deleteButton, in: app)
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3))
        deleteButton.tap()
        
        let confirmationDialog = app.sheets["Delete this drink?"]
        XCTAssertTrue(confirmationDialog.waitForExistence(timeout: 3))
        
        let dismissalPoint = app.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)
        )
        XCTAssertFalse(
            confirmationDialog.frame.contains(dismissalPoint.screenPoint),
            "The dismissal tap must be outside the conifmration dialog"
        )
        dismissalPoint.tap()
        
        XCTAssertTrue(confirmationDialog.waitForNonExistence(timeout: 3))
        XCTAssertTrue(deleteButton.exists, "Cancelling should keep the detail open")
        
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(
            totalAmountText.wait(for: \.label, toEqual: "330 ml", timeout: 3)
        )
    }
    
    // Given two saved drinks, when the user confirms a history reset,
    // then Profile closes, Stats is empty, and Add Drink has no recents.
    @MainActor
    func testDeletingAllDrinksClearsHistoryAndRecents() throws {
        
        let app = launchIsolatedApp()
        let addDrinkButton = app.buttons["addDrinkActionButton"]
        let submitButton = app.buttons["addDrinkSubmitButton"]

        for _ in 0..<2 {
            XCTAssertTrue(addDrinkButton.waitForExistence(timeout: 3))
            addDrinkButton.tap()
            selectWaterCategory(in: app)
            XCTAssertTrue(submitButton.waitForExistence(timeout: 3))
            submitButton.tap()
            XCTAssertTrue(submitButton.waitForNonExistence(timeout: 3))
        }

        let totalAmountText = app.staticTexts["todayTotalAmountText"]
        XCTAssertTrue(
            totalAmountText.wait(for: \.label, toEqual: "660 ml", timeout: 3)
        )

        let profileButton = app.buttons["profileButton"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 3))
        profileButton.tap()

        let resetButton = app.buttons["deleteAllDrinksButton"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 3))
        resetButton.tap()

        let confirmationDialog = app.sheets["Delete all drinks?"]
        XCTAssertTrue(confirmationDialog.waitForExistence(timeout: 3))

        // Target the inner action button in the native confirmation hierarchy.
        let confirmButton = confirmationDialog.buttons
            .matching(identifier: "confirmDeleteAllDrinksButton")
            .children(matching: .button)
            .element 
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3))
        confirmButton.tap()

        XCTAssertTrue(resetButton.waitForNonExistence(timeout: 3))
        app.tabBars.buttons["Stats"].tap()
        XCTAssertTrue(
            app.staticTexts["No persisted drinks yet"].waitForExistence(timeout: 3)
        )

        app.tabBars.buttons["Today"].tap()
        addDrinkButton.tap()
        XCTAssertTrue(submitButton.waitForExistence(timeout: 3))
        XCTAssertFalse(app.scrollViews["addDrinkRecentsScrollView"].exists)
    }
    
    // Given a saved drink and customised profile settings, when history is
    // deleted, then the selected unit and hydration goal remain unchanged.
    @MainActor
    func testDeletingAllDrinksPreservesProfileSettings() throws {
        let app = launchIsolatedApp()

        let addDrinkButton = app.buttons["addDrinkActionButton"]
        XCTAssertTrue(addDrinkButton.waitForExistence(timeout: 3))
        addDrinkButton.tap()
        selectWaterCategory(in: app)

        let submitButton = app.buttons["addDrinkSubmitButton"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 3))
        submitButton.tap()
        XCTAssertTrue(submitButton.waitForNonExistence(timeout: 3))

        let profileButton = app.buttons["profileButton"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 3))
        profileButton.tap()

        let selectedUnit = app.segmentedControls["displayUnitPicker"]
            .buttons["US fl oz"]
        XCTAssertTrue(selectedUnit.waitForExistence(timeout: 3))
        selectedUnit.tap()
        XCTAssertTrue(selectedUnit.isSelected)

        let goalText = app.staticTexts["dailyHydrationGoalText"]
        XCTAssertTrue(goalText.waitForExistence(timeout: 3))
        let originalGoal = goalText.label

        let goalStepper = app.steppers["dailyHydrationGoalStepper"]
        
        let incrementButton = goalStepper.buttons["dailyHydrationGoalStepper-Increment"]
        XCTAssertTrue(incrementButton.waitForExistence(timeout: 3))
        incrementButton.tap()
        XCTAssertNotEqual(goalText.label, originalGoal)
        let selectedGoal = goalText.label

        let resetButton = app.buttons["deleteAllDrinksButton"]
        resetButton.tap()

        let confirmationDialog = app.sheets["Delete all drinks?"]
        XCTAssertTrue(confirmationDialog.waitForExistence(timeout: 3))

        // Select the inner button exposed by the confirmation action.
        let confirmButton = confirmationDialog.buttons
            .matching(identifier: "confirmDeleteAllDrinksButton")
            .children(matching: .button)
            .element
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3))
        confirmButton.tap()
        XCTAssertTrue(resetButton.waitForNonExistence(timeout: 3))

        // Reopen Profile and check the customised settings survived.
        profileButton.tap()
        XCTAssertTrue(selectedUnit.waitForExistence(timeout: 3))
        XCTAssertTrue(selectedUnit.isSelected)
        XCTAssertTrue(
            goalText.wait(for: \.label, toEqual: selectedGoal, timeout: 3)
        )
    }
    
//    @MainActor
//    func testLaunchPerformance() throws {
//        // This measures how long it takes to launch your application.
//        measure(metrics: [XCTApplicationLaunchMetric()]) {
//            XCUIApplication().launch()
//        }
//    }
}
