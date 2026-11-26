import Testing
@testable import Watered

struct AddDrinkPreparationPresentationTests {
    // Alcohol always reserves the toggle and ABV controls, without inventing unsupported alternatives.
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

    // All drinks in these categories retain their row slots; only catalogue-supported options are editable.
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

    // New catalogue definitions work without adding their drink IDs to presentation code.
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
