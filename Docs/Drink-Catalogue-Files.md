# Drink Catalogue Files

The app loads `Watered/Watered/Resources/DrinkCatalogue/Manifest.json` and the
category JSON files listed in it. Xcode copies this directory into the app bundle
as a folder resource. Files are not discovered by scanning the directory.

## Versions

- `manifestVersion` identifies the manifest's file-layout format, currently `1`.
- `schemaVersion` identifies the assembled catalogue data contract, currently `2`.
- `version` identifies the catalogue content release, currently `development-3`.

Content version `development-3` removes Mineral water, Frappe, Mocha, Decaf coffee and
Turkish coffee from new selection, leaving 11 definitions. The manifest layout remains version 1. Schema 2 permits zero-shot preparations;
schema 1 remains readable and retains its positive-shot validation rule. Existing snapshot-backed
Entries for removed drinks retain their saved facts and remain readable in history, but
are excluded from Recents. New logs capture the new content version; saved history
is never rebuilt from newer definitions.

## Editing Content

Each manifest category provides its ID, name, sort order and JSON filename. Its
file is an array of drink definitions whose `categoryID` matches that category.
Filenames are JSON basenames within this directory, not paths or remote URLs.

To add a reviewed drink to an existing category, edit that category's file. To add
a category, add its definition file and one manifest entry. Use the supported
data rules and update the content version when approved definitions change.
No category-specific Swift code or generated combined JSON is required.

The loader assembles files in manifest order and validates the complete result,
including cross-file duplicate IDs. Missing, malformed or invalid required files
fail the load rather than exposing a partial catalogue. Unlisted files are ignored.

Only the four Water and seven Coffee definitions are approved in this slice.
The remaining catalogue population, estimates and metadata review stay in #101.

## Calculation compatibility

Calculation version `2` accepts zero for known per-shot caffeine rules (yielding
zero); negative counts remain invalid. Unknown rules still return unknown, including
at zero shots. Historical snapshots keep their original catalogue/schema/calculation
versions and estimates. No database reset, historical recalculation or app marketing
version change accompanies this content update.

## Coffee preparation

All seven coffees support regular and decaf, defaulting to regular. Latte,
Cappuccino, Espresso and Americano support 0–4 shots, defaulting to 2. Iced coffee,
Coffee with milk and Cold brew have no shot selector until their recipes are defined.
These preparation choices are included in `development-3`; caffeine estimates stay
explicitly unknown for both variants. Changing shots does not resize the drink or
change its hydration ratio. Milk options remain deferred.
