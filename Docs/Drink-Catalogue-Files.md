# Drink Catalogue Files

The app loads `Watered/Watered/Resources/DrinkCatalogue/Manifest.json` and the
category JSON files listed in it. Xcode copies this directory into the app bundle
as a folder resource. Files are not discovered by scanning the directory.

## Versions

- `manifestVersion` identifies the manifest's file-layout format, currently `1`.
- `schemaVersion` identifies the assembled catalogue data contract, currently `2`.
- `version` identifies the catalogue content release, currently `development-4`.

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

All seven coffees support regular and decaf, defaulting to regular. Content
`development-4` implements the defaults reviewed with Frank on 7 November 2026:

| Drink | Default shots (0–4 supported) | Regular caffeine | Decaf caffeine |
| --- | ---: | ---: | ---: |
| Espresso, Cappuccino | 1 | 60 mg/shot | 5 mg/shot |
| Latte, Americano, Iced coffee | 2 | 60 mg/shot | 5 mg/shot |
| Coffee with milk | Not applicable | 100 mg/250 ml | 5 mg/250 ml |
| Cold brew | Not applicable | 200 mg/400 ml | 10 mg/200 ml |

Volume-based JSON concentrations are mg per 100 ml: Coffee with milk uses 40/2;
Cold brew uses 50/5 (regular/decaf). All calculations use unrounded physical volume.
Shot-based estimates depend only on chosen shots, including known zero at zero shots.
Iced coffee now means an espresso-based recipe. Coffee with milk retains the generic
225 ml brewed coffee + 25 ml milk reference; Cold brew means ready-to-drink, not concentrate.

These are approved product assumptions, not measured caffeine or universal averages.
[Mayo Clinic's espresso reference](https://www.mayoclinic.org/healthy-lifestyle/nutrition-and-healthy-eating/in-depth/caffeine/art-20049372)
lists 63 mg per 30 ml regular espresso; 60 mg is the rounded default.
[McCusker et al.](https://pubmed.ncbi.nlm.nih.gov/17132260/) measured 3–15.8 mg per
commercial decaf shot in a small sample; 5 mg is a chosen assumption, not its mean.
The brewed-coffee and cold-brew defaults were selected from user-supplied ranges;
their source provenance was not independently verified. They are separate recipes,
not a universal decaffeination percentage.

Hydration percentages remain fixed per drink, independent of shots and decaf:
Latte 90.6%, Cappuccino 91%, Iced coffee 99%, Espresso 95%, Coffee with milk 98.1%,
Cold brew 99%, Americano 99.4%. Water definitions are unchanged. These are goal-credit
assumptions, not measured water content or physiological retention. Contribution
percentages display rounded toward negative infinity to at most one decimal;
calculation precision and saved estimates are unchanged. Daily progress formatting
is separate. Milk customisation, alcohol policy and HealthKit mapping remain deferred.

Only content changes: manifest version 1, schema 2 and calculation version 2 remain
unchanged. Existing saved unknown caffeine stays unknown. Supported repeats create
new entries with current estimates and retain the original selected shots, even if
the default changed. Older Iced coffee snapshots have no shot count, so they remain
readable but are excluded from Recents as unsupported preparations; no shots are
invented for history. This slice does not close the wider research in #102.
