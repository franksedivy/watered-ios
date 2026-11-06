import Testing
@testable import Watered

@MainActor
struct AddDrinkCategoryDefaultsTests {
    @Test
    func preferredDrinksDoNotDependOnTheirPosition() {
        let still = drink("still-water", category: "water")
        let latte = drink("latte", category: "coffee")
        #expect(AddDrinkCategoryDefaults.drink(in: "water", from: [
            drink("sparkling-water", category: "water"), still
        ]) == still)
        #expect(AddDrinkCategoryDefaults.drink(in: "coffee", from: [
            drink("espresso", category: "coffee"), latte
        ]) == latte)
    }

    @Test
    func unavailablePreferredDrinkFallsBackToFirstActiveDrink() {
        let sparkling = drink("sparkling-water", category: "water")
        #expect(AddDrinkCategoryDefaults.drink(in: "water", from: [
            drink("still-water", category: "water", retired: true), sparkling
        ]) == sparkling)
    }

    @Test
    func otherCategoriesUseTheirFirstActiveDrink() {
        let tea = drink("black-tea", category: "tea")
        #expect(AddDrinkCategoryDefaults.drink(in: "tea", from: [tea]) == tea)
    }

    @Test
    func emptyRetiredAndWrongCategoryListsHaveNoDefault() {
        #expect(AddDrinkCategoryDefaults.drink(in: "water", from: []) == nil)
        #expect(AddDrinkCategoryDefaults.drink(in: "water", from: [
            drink("still-water", category: "water", retired: true),
            drink("latte", category: "coffee")
        ]) == nil)
    }

    private func drink(_ id: String, category: String, retired: Bool = false) -> DrinkDefinition {
        DrinkDefinition(id: id, name: id, categoryID: category, sortOrder: 0, isRetired: retired)
    }
}
