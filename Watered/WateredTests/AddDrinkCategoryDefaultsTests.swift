import Testing
@testable import Watered

@MainActor
struct AddDrinkCategoryDefaultsTests {
    // GIVEN Still water and Latte appear after other choices in their categories,
    // THEN the preferred drinks remain the defaults regardless of list position.
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

    // GIVEN the preferred Still water definition is retired,
    // THEN Water defaults to the first active alternative.
    @Test
    func unavailablePreferredDrinkFallsBackToFirstActiveDrink() {
        let sparkling = drink("sparkling-water", category: "water")
        #expect(AddDrinkCategoryDefaults.drink(in: "water", from: [
            drink("still-water", category: "water", retired: true), sparkling
        ]) == sparkling)
    }

    // GIVEN a category without an explicit preferred drink,
    // THEN its first active drink becomes the default.
    @Test
    func otherCategoriesUseTheirFirstActiveDrink() {
        let tea = drink("black-tea", category: "tea")
        #expect(AddDrinkCategoryDefaults.drink(in: "tea", from: [tea]) == tea)
    }

    // GIVEN empty choices or only retired and wrong-category definitions,
    // THEN no default drink is returned for the requested category.
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
