# Drink Catalogue Files

The app loads `Watered/Watered/Resources/DrinkCatalogue/Manifest.json` and the
category JSON files listed in it. Xcode copies this directory into the app bundle
as a folder resource. Files are not discovered by scanning the directory.

## Versions

- `manifestVersion` identifies the manifest's file-layout format, currently `1`.
- `schemaVersion` identifies the assembled catalogue data contract, currently `3`.
- `version` identifies the catalogue content release, currently `development-8`.

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

The current seed contains 25 drinks: four Water, seven Coffee, ten Tea and four Juices definitions.
The remaining catalogue population, estimates and metadata review stay in #101.

## Caffeine and alcohol structure (schema 3, #102)

Every definition explicitly declares `caffeine` and `alcohol`. Neither missing fields
nor `null` mean zero. Water uses:

```json
"caffeine": { "kind": "none" },
"alcohol": { "kind": "none" }
```

`none` means known absence; `unknown` means no supported content estimate. Both kinds
contain only `kind`. Coffee groups its preparation choices and default together:

```json
"caffeine": {
    "kind": "options",
    "defaultVariant": "regular",
    "options": [
        { "variant": "regular", "rule": { "kind": "perShot", "amount": 60 } },
        { "variant": "decaf", "rule": { "kind": "perShot", "amount": 5 } }
    ]
},
"alcohol": { "kind": "none" }
```

The existing `shotConfiguration` remains on shot-based drink definitions. Options
must be nonempty, have unique variants and include the default. Numeric caffeine
rules remain finite, nonnegative mg per shot or mg per 100 ml. An option may retain
an explicitly unknown rule. Schema 3 rejects shot configuration without a per-shot rule.

Alcohol uses `{"kind":"abv","value":0.05}` for a known 5% ABV, or
`{"kind":"unknown"}` when unsupported. ABV must be a finite fraction from 0 to 1.
Alcohol content does not automatically select a hydration policy. A separately
selected `hydrationContributionRule: {"kind":"alcohol"}` requires known ABV and
uses that single value with the existing calculation. Do not also supply
`defaultABV` in the hydration object. This is schema support, not approval of an
alcohol coefficient, an alcoholic seed drink, custom ABV UI or HealthKit mapping.

Schema 3 rejects old top-level caffeine fields, parent booleans, extra fields in
content objects, contradictory numeric rule fields and missing required values.
The loader still reads schema 1/2 definitions with their original caffeine fields
and alcohol hydration ABV. Where those definitions did not declare alcohol, it
stays unknown. New encoding uses the nested structure.

The in-memory definition exposes derived preparation adapters so water can still
resolve a known zero and repeat existing `regular` snapshots. There is no extra
stored caffeine flag or duplicate authored ABV. Saved entries do not persist these
catalogue definitions: their snapshot and database formats are unchanged. No
history rewrite or database migration accompanies schema 3. New logs and supported
repeats capture the active content version / schema 3; older snapshots retain their original
versions, preparation and known or unknown estimates.

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

The coffee-value update in `development-4` changed content only. The subsequent
`development-5` structure update uses schema 3; manifest version 1 and calculation
version 2 remain unchanged. Existing saved unknown caffeine stays unknown. Supported repeats create
new entries with current estimates and retain the original selected shots, even if
the default changed. Older Iced coffee snapshots have no shot count, so they remain
readable but are excluded from Recents as unsupported preparations; no shots are
invented for history. This slice does not close the wider research in #102.


## Plain tea — approved 8 November 2026 (#101 / #102)

Content `development-6` adds `tea.json`, category `tea` after Coffee, with Black,
Green, White and Herbal tea in that order. The first entry, Black tea, is the category
selection default. Each represents plain brewed tea without milk or sugar, with the
same estimates hot or cold. There is no temperature, strength or steeping-time control.

| ID | Serving default | Hydration credit | Regular caffeine / 250 ml | Decaf / 250 ml |
| --- | ---: | ---: | ---: | ---: |
| `black-tea` | 250 ml | 99% | 50 mg | 5 mg |
| `green-tea` | 250 ml | 99% | 30 mg | 5 mg |
| `white-tea` | 250 ml | 99% | 30 mg | 5 mg |
| `herbal-tea` | 250 ml | 99% | 0 mg | Not applicable |

Black, Green and White default to regular and support decaf. Their volume-based
JSON concentrations are respectively 20, 12 and 12 mg/100 ml regular, and 2 mg/100 ml
decaf. Herbal uses `caffeine: {"kind":"none"}` and has no decaf selector. It means
caffeine-free infusions such as plain peppermint, chamomile or rooibos, excluding
blends containing tea leaves, mate or added caffeine. All four declare no alcohol
and have no shot configuration. Caffeine scales with physical volume; hydration
stays at the fixed ratio. A 500 ml black tea resolves to 495 ml credit and 100 mg
regular or 10 mg decaf caffeine. Raw intake remains 500 ml.

A catalogue serving is applied while the form's volume remains untouched. Explicitly
chosen amounts and restored drafts take precedence over serving defaults, including
when changing drinks or display units. Exact 250 ml is retained in ounce displays
rather than snapped to a preset. Existing fallback artwork and category symbol are
used; final custom artwork is outside this slice.

These are approved product defaults, not measured universal averages. The 99% is
an accounting assumption, not a demonstrated 1% physiological loss or caffeine
penalty. A [black-tea hydration trial](https://pubmed.ncbi.nlm.nih.gov/21450118/)
found no significant difference from water under its studied conditions; this does
not establish the chosen coefficient for all four teas.
[Mayo Clinic](https://www.mayoclinic.org/healthy-lifestyle/nutrition-and-healthy-eating/in-depth/caffeine/art-20049372)
lists 48 mg black and 29 mg green per 237 ml, supporting rounded 50/30 mg references
for 250 ml. White tea's 30 mg is an explicit shared assumption; a
[brewed-tea study](https://pubmed.ncbi.nlm.nih.gov/19007524/) found overlapping caffeine
amounts across tea types and less than 12 mg per serving in its decaf samples.
[Bigelow's decaf green tea](https://www.bigelowtea.com/collections/bigelow-classics/products/green-tea-decaf-40-count)
reports 1–8 mg; 5 mg per 250 ml is our shared decaf assumption, with limited direct
evidence for decaf white tea. Herbal zero applies to the defined caffeine-free recipe.
Serving temperature equivalence is a simplifying product rule, not a claim that
all hot- and cold-brewing methods extract identical caffeine.

Schema 3, manifest 1 and calculation version 2 stay unchanged. Existing Water/Coffee
content, saved snapshots and persistence formats are unchanged. Supported repeats
create new entries with active rules; no historical recalculation or database reset.
The subsequent six-tea batch is recorded below. Other categories stay open under #101/#102; alcohol
policy and HealthKit mapping remain separate.

## Remaining teas — approved 8 November 2026 (#99 / #101 / #102)

Content `development-7` appends these six drinks after the four plain teas, in the
order below. That release contained 21 drinks: four Water, seven Coffee and ten Tea.
Black tea remains the Tea category default. Display names are exactly as listed.

| ID | Display name | Serving default | Hydration credit | Caffeine / 250 ml | Optional preparation |
| --- | --- | ---: | ---: | ---: | --- |
| `matcha` | Matcha | 250 ml | 99% | 60 mg | None |
| `matcha-latte` | Matcha latte | 250 ml | 92% | 60 mg | None |
| `bubble-milk-tea` | Bubble milk tea | 250 ml | 93% | 60 mg | None |
| `bubble-fruit-tea` | Bubble fruit tea | 250 ml | 95% | 30 mg | Caffeine-free: 0 mg |
| `yerba-mate` | Yerba mate | 250 ml | 99% | 80 mg | None |
| `iced-tea` | Iced tea | 330 ml | 95% | 20 mg | Caffeine-free: 0 mg |

All start with regular caffeine. The two **Caffeine-free** toggles are off by default;
these represent recipes without a caffeinated tea base, not decaffeinated tea.
Hydration percentages stay fixed when the toggle changes. There are no shot,
strength, temperature, flavour, sweetness, topping or refill controls. All declare
no alcohol. Plain matcha, matcha latte and brewed yerba mate use the same estimates
hot or cold. Iced tea specifically means a lightly sweetened bottled/canned drink,
not ordinary brewed tea served cold or a mate energy drink.

Bubble tea amounts cover drinkable liquid only, excluding pearls, jelly and ice
left behind. Caffeine scales with volume at the assumed recipe strength. JSON uses
24/24/24/12/32/8 mg per 100 ml respectively. A 330 ml regular Iced tea records
330 ml intake, 313.5 ml hydration credit and 26.4 mg caffeine; caffeine-free records
0 mg while retaining the same intake and credit. Serving defaults apply only while
volume is untouched; explicit choices and restored drafts keep their physical amount.

### Reference recipes and evidence limits

These are approved product estimates, not measured universal hydration coefficients
or brand averages. No extra caffeine penalty is applied to hydration.

- **Matcha:** 2 g powder diluted to 250 ml water. The existing audit proposed 99%.
  [Ippodo](https://ippodotea.com/collections/matcha) reports about 64 mg caffeine for
  2 g powder; 60 mg is our rounded dose estimate. Our 250 ml dilution is a product
  recipe assumption, not Ippodo's traditional serving volume.
- **Matcha latte:** 2 g powder, 50 ml water and 200 ml milk. Water at 100% and the
  existing generic milk accounting input at 90% give `(50 + 200 × 0.90) / 250 = 92%`.
  The same powder dose gives 60 mg caffeine. This is our recipe, not the
  [Ippodo latte recipe](https://ippodotea.com/blogs/recipes-to-brew-japanese-tea/matcha-latte-recipe),
  which uses a stronger 3 g dose. No milk-type customization.
- **Bubble milk tea:** the audit's reference liquid recipe is 150 ml lightly
  sweetened tea at 95% plus 100 ml milk at 90%, giving 93%. Its 60 mg caffeine is a
  separate stronger-tea assumption, not a dilution of our plain black-tea default.
  [Gong cha black milk tea](https://www.gong-cha.co.kr/brand/menu/product_detail?category=001006&no=53)
  lists 106 mg per 414 ml hot serving (about 64 mg/250 ml), supporting the ballpark.
  Recipes using creamer, different tea strength or sugar quantities can differ.
- **Bubble fruit tea:** brewed tea with fruit flavouring/syrup; caffeine-free uses
  a fruit base without caffeinated tea. The 95% follows our lightly sweetened tea
  accounting assumption. The 30 mg caffeine default is informed by
  [Gong cha fruit-tea examples](https://www.gong-cha.co.kr/brand/menu/product_nutrition)
  around 21–38 mg per 250 ml of cup capacity. Those cold servings can include ice
  and are not a precise validation of the liquid-only estimate.
- **Yerba mate:** plain brewed mate. The existing audit proposed 99%; a
  [producer FAQ](https://yerbamatecastiellousa.com/pages/faqs) gives approximately
  70–80 mg per 8-ounce cup. The agreed 80 mg/250 ml is a rounded generic estimate;
  leaf quantity, brewing and repeated infusions vary substantially. No separate
  refill calculation or bottled energy-style mate is represented.
- **Iced tea:** lightly sweetened ready-to-drink tea. The existing audit proposed
  95%; 20 mg/250 ml is an agreed generic assumption, not a demonstrated market
  average. Brand strength varies: a
  [Pure Leaf producer label](https://digitalassets.pepsico.com/m/26ce7d7e30d79725/original/00048500020630_L1.pdf)
  lists 45 mg/355 ml, substantially higher. This evidence establishes variability,
  not the selected 20 mg default. Caffeine-free is known zero for a caffeine-free base.

### Compatibility and scope

The additive `caffeine-free` variant has its own stored raw value, distinct from
`regular` and `decaf`; validation requires a known zero per-volume rule. Existing
raw values, stored fields and snapshots are unchanged. Manifest 1, schema 3 and
calculation version 2 remain unchanged; the catalogue object shape is unchanged.
Older app builds do not understand the new variant, so new catalogue content must
ship with its supporting app code. No data migration, reset or historical
recalculation is performed. Saved unknowns remain unknown; supported repeats create
new entries under current rules. Recents label the preparation “Caffeine-free”.
Stats retains its existing behaviour of hiding the caffeine section for known zero.

This completes the agreed ten-entry Tea membership, not the wider catalogue under
#101/#102 or integration verification under #105. New artwork uses existing
fallbacks until supplied. Sheet positioning/animation remains separate in #149;
alcohol and HealthKit mapping remain outside this batch. No PR is created without
Frank's explicit request.

## Juices — approved 9 November 2026 (#99 / #101 / #102)

Content `development-8` adds `juices.json` after Tea. The seed now has 25 drinks.
Manifest 1, schema 3 and calculation version 2 are unchanged. All four drinks have
250 ml defaults, known zero caffeine (`caffeine.kind: none`), no alcohol
(`alcohol.kind: none`) and no preparation or flavour controls.

| ID / display name, in order | Hydration contribution | Credit for 250 ml | Scope |
| --- | ---: | ---: | --- |
| `fruit-juice` / Fruit juice | 90% | 225 ml | 100% fruit juice; no sweetened/diluted fruit drinks or added caffeine |
| `vegetable-juice` / Vegetable juice | 95% | 237.5 ml | 100% vegetable juice, including vegetable-only blends; excludes fruit-and-vegetable blends |
| `smoothie` / Smoothie | 85% | 212.5 ml | Drinkable fruit/vegetable smoothies and blends; excludes milk, yoghurt and protein-based versions or caffeinated additions |
| `aloe-vera-drink` / Aloe vera drink | 90% | 225 ml | Ready-to-drink diluted aloe beverage, including pulp; representative estimate uses a sweetened bottled drink, excluding concentrates, supplements and caffeinated blends |

These are approved generic Watered accounting assumptions, not measured physiological
hydration fractions or market averages. They do not imply that the remainder causes
fluid loss. Fluid intake retains the entire consumed volume; goal credit uses the
fixed ratio. No extra caffeine penalty or health benefit is inferred.

### Evidence and limitations

- Fruit juice's 90% is a newly approved generic assumption. The
  [USDA fruit composition tables](https://www.ars.usda.gov/ARSUserFiles/80400535/Data/SR/SR28/reports/sr28fg09.pdf)
  report raw orange juice at 88.3 g water per 100 g, but composition by mass does not
  establish a volume-based hydration coefficient across fruit juices. An
  [orange-juice hydration trial](https://pubmed.ncbi.nlm.nih.gov/26702122/) does not
  establish a 10% hydration loss relative to water.
- Vegetable juice retains the audit's provisional 95%. The ingredient list for
  [V8 Original](https://www.campbells.com/v8/products/v8-vegetable-juice/original-100-vegetable-juice/)
  supports the vegetable-only, non-caffeinated example; it does not establish 95%
  physiological credit. Vegetable blends and solids vary.
- Smoothie retains the audit's provisional 85% for drinkable puree and juice.
  [Innocent's ingredient information](https://www.innocentdrinks.co.uk/get-in-touch/faqs)
  provides recipe context, not a measured coefficient. A component-based calculation
  remains unsupported without representative puree/juice proportions and rules.
- Aloe vera drink retains the audit's provisional 90%.
  [ALO Original](https://alodrink.com/alo-original/alo-exposed/) lists water, aloe juice,
  pulp and sweeteners without caffeine sources;
  [Aloevine Original](https://aloevine.com/flavors/original/) lists 8% aloe gel.
  Neither label establishes a hydration fraction; gel percentage is not hydration
  contribution. Unsweetened aloe water may differ from this representative recipe.

The [manufacturer audit](https://github.com/franksedivy/watered-ios/wiki/Research:-Drink-Manufacturer-Audit)
retains historical proposals; the approved values above supersede its older
unreviewed juice scores. Zero caffeine applies to the defined recipes, not tea,
coffee, guarana or energy blends.

### Presentation and history

Juices uses iOS orange (`Color.orange`) and `takeoutbag.and.cup.and.straw`. Selected
drink tiles retain the existing category-coloured border and neutral fill; names
retain the existing primary text style (black in light appearance). Bundled artwork
can be supplied under the four stable IDs; until then the existing fallback renders.

Existing Water/Coffee/Tea JSON, saved snapshots, unknown estimates and persistence
fields remain unchanged. Only new logs capture development-8; repeating a supported
recent drink resolves current rules without changing its original record. Serving
defaults apply only to untouched volume; chosen and restored amounts remain intact.
No database reset, HealthKit mapping, alcohol-policy or #149 sheet-layout change is
included. Tests cover catalogue membership, units, saved-fact round trips, repeats,
no preparation controls, volume defaults and saved hydration totals.
