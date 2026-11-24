import Testing
@testable import Watered

struct AddDrinkArtworkSizeTests {
    @Test func configuredArtworkAndUnconfiguredDrinks() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        #expect(catalogue.drink(withID: "espresso") != nil)
        #expect(catalogue.drink(withID: "sparkling-wine") != nil)
        #expect(AddDrinkArtworkSize.resolve(drinkID: "espresso") == .small)
        #expect(AddDrinkArtworkSize.resolve(drinkID: "sparkling-wine") == .medium)
        for drink in catalogue.drinks where !["espresso", "sparkling-wine"].contains(drink.id) {
            #expect(AddDrinkArtworkSize.resolve(drinkID: drink.id) == .large)
        }
        #expect(AddDrinkArtworkSize.resolve(drinkID: "new-unconfigured-drink") == .large)
    }
}
