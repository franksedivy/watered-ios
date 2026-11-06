//
//  AddDrinkCategoryDefaults.swift
//  Watered
//

/// Temporary UI defaults for the category-first prototype, not a persisted preference.
/// The highlighted card always shows the actual drink that will be logged.
nonisolated enum AddDrinkCategoryDefaults {
    static func drink(in categoryID: String, from drinks: [DrinkDefinition]) -> DrinkDefinition? {
        let activeDrinks = drinks.filter { $0.categoryID == categoryID && !$0.isRetired }
        let preferredID: String?
        switch categoryID {
        case "water": preferredID = "still-water"
        case "coffee": preferredID = "latte"
        default: preferredID = nil
        }
        return activeDrinks.first { $0.id == preferredID } ?? activeDrinks.first
    }
}
