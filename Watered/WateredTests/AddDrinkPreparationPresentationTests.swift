import Foundation
import Testing
@testable import Watered

struct AddDrinkPreparationPresentationTests {
    // GIVEN an alcohol drink with a selected strength and optional non-alcoholic preparation,
    // THEN switching modes preserves its scale and selection, showing the non-alcoholic upper bound only when supported.
    @Test func nonAlcoholicSliderKeepsOriginalScaleAndSelection() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        for drink in catalogue.activeDrinks(inCategoryID: "alcohol") {
            let rows = try #require(AddDrinkPreparationPresentation(definition: drink).alcoholRows)
            let chosen = try #require(rows.configuration.supportedABVs.last)
            let alcoholic = rows.strength(isNonAlcoholic: false, selectedABV: chosen)
            #expect(!alcoholic.isUpperBound)
            #expect(alcoholic.values[alcoholic.selectedIndex] == chosen)
            let alternative = rows.strength(isNonAlcoholic: true, selectedABV: chosen)
            #expect(alternative.values == alcoholic.values)
            #expect(alternative.selectedIndex == alcoholic.selectedIndex)
            #expect(alternative.title == alcoholic.title)
            if let preparation = rows.configuration.nonAlcoholic {
                #expect(alternative.isUpperBound)
                #expect(alternative.maximumNonAlcoholicABV == preparation.maximumABV)
                #expect(alternative.accessibilityValue.contains("exact amount unknown"))
            } else {
                #expect(!alternative.isUpperBound)
                #expect(alternative.values[alternative.selectedIndex] == chosen)
            }
            let restored = rows.strength(isNonAlcoholic: false, selectedABV: chosen)
            #expect(restored.values[restored.selectedIndex] == chosen)
        }
    }

    // GIVEN each bundled alcohol drink and its catalogue configuration,
    // THEN Alcohol reserves the same controls and height while enabling only supported non-alcoholic alternatives.
    @Test func alcoholRowsFollowCatalogueAvailability() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let supported = ["beer", "cider", "wine", "cocktail", "sparkling-wine"]
        for drink in catalogue.activeDrinks(inCategoryID: "alcohol") {
            let presentation = AddDrinkPreparationPresentation(definition: drink)
            let rows = try #require(presentation.alcoholRows)
            #expect(rows.isNonAlcoholicEnabled == supported.contains(drink.id))
            #expect(rows.configuration == drink.alcohol.configuration)
            #expect(presentation.caffeineRow == nil)
            #expect(!presentation.showsShots)
            #expect(AddDrinkPreparationPresentation.sheetHeight(categoryID: "alcohol", definition: drink) == 780)
        }
    }

    // GIVEN bundled Coffee, Tea and Soft Drinks definitions with differing preparation capabilities,
    // THEN category rows and heights stay stable, only supported options are enabled, and Water has no preparation rows.
    @Test func bundledCategoryRowsAndAvailability() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        for category in ["coffee", "tea", "soft-drinks"] {
            for drink in catalogue.activeDrinks(inCategoryID: category) {
                let presentation = AddDrinkPreparationPresentation(definition: drink)
                let row = try #require(presentation.caffeineRow)
                let variants = drink.caffeineOptions.map(\.variant)
                #expect(row.isEnabled == (variants.contains(.regular) && variants.contains(row.alternative)))
                #expect(presentation.showsShots == (category == "coffee"))
                #expect(presentation.shotConfiguration == drink.shotConfiguration)
                #expect(AddDrinkPreparationPresentation.sheetHeight(categoryID: category, definition: drink)
                    == (category == "coffee" ? 720 : 660))
            }
        }
        for id in ["herbal-tea", "matcha", "lemonade", "tonic-water"] {
            let drink = try #require(catalogue.drink(withID: id))
            let row = try #require(AddDrinkPreparationPresentation(definition: drink).caffeineRow)
            #expect(!row.isEnabled)
            #expect(row.alternative == (drink.categoryID == "tea" ? .decaf : .caffeineFree))
        }
        for id in ["bubble-fruit-tea", "iced-tea", "cola"] {
            let drink = try #require(catalogue.drink(withID: id))
            let row = try #require(AddDrinkPreparationPresentation(definition: drink).caffeineRow)
            #expect(row.isEnabled)
            #expect(row.alternative == .caffeineFree)
        }
        let water = try #require(catalogue.drink(withID: "still-water"))
        #expect(!AddDrinkPreparationPresentation(definition: water).hasRows)
    }

    // GIVEN new Soft Drinks definitions with and without a caffeine-free alternative,
    // THEN capability determines toggle availability, and an unselected category retains the compact sheet height.
    @Test func syntheticDefinitionsUseCapabilitiesNotDrinkNames() {
        let supported = DrinkDefinition(
            id: "new-soft-drink", name: "New drink", categoryID: "soft-drinks", sortOrder: 1,
            isRetired: false, caffeineOptions: [
                CaffeineOption(variant: .regular, rule: .unknown),
                CaffeineOption(variant: .caffeineFree, rule: .unknown)
            ]
        )
        let unsupported = DrinkDefinition(
            id: "another-soft-drink", name: "Another drink", categoryID: "soft-drinks", sortOrder: 2,
            isRetired: false
        )
        #expect(AddDrinkPreparationPresentation(definition: supported).caffeineRow?.isEnabled == true)
        #expect(AddDrinkPreparationPresentation(definition: unsupported).caffeineRow?.isEnabled == false)
        #expect(AddDrinkPreparationPresentation.sheetHeight(categoryID: nil, definition: nil) == 440)
    }
}
