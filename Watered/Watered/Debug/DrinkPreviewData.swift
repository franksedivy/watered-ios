#if DEBUG
import Foundation

/// Supplies validated catalogue entries for Xcode previews only.
nonisolated enum DrinkPreviewData {
    /// Creates a preview drink using a known bundled definition and amount.
    static func entry(
        drinkID: String,
        amount: DrinkAmount,
        date: Date = Date()
    ) -> DrinkEntry {
        let catalogue = try! DrinkCatalogueLoader().load()
        let resolver = try! DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        return try! AddDrinkDraft(
            drinkID: drinkID,
            volumeValue: amount.value,
            unit: amount.unit
        ).drinkEntry(using: resolver, date: date)
    }
}
#endif
