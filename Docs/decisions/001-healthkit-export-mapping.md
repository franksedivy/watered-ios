# 001 — Capture water content independently of hydration credit

- Status: Structure and quantity direction accepted by Frank on 10 November 2026. All catalogue water estimates are approved; alcohol conversion approved on 14 November. Lifecycle policy was subsequently approved in [decision 002](002-healthkit-export-lifecycle.md) and implemented through #109/#110.
- Owner/reviewer: Frank Sedivy.
- Related: [#95](https://github.com/franksedivy/watered-ios/issues/95), parent [#106](https://github.com/franksedivy/watered-ios/issues/106), mapping [#108](https://github.com/franksedivy/watered-ios/issues/108).
- Supersedes: the narrow Still/Sparkling/Infused-only water policy approved earlier in this chat. The subsequent full-beverage-volume suggestion was also rejected.

## Context and decision

Current implementation note, 25 November 2026: the mapping work merged in PR #164;
#107–#111 now provide authorization, frozen mapping, durable export, cleanup and
Profile controls. The handoff and verification sections below retain their original
slice-specific evidence, not the current delivery status. See [Architecture](../ARCHITECTURE.md)
and [Testing](../TESTING.md) for the implemented boundaries and recorded evidence.
Final release reconciliation remains #113; this decision does not approve a release.

Consumed beverage volume, estimated water content, hydration-goal contribution and
caffeine mass are separate quantities. The reviewed catalogue had only beverage
volume, goal credit and caffeine mass. Its goal-credit factors must not be relabelled
as water content. Alcohol's zero goal credit does not mean the beverage contains no water.

Frank chose to represent the water contained in a drink in HealthKit, keeping
hydration scoring inside Watered. The illustrative 330 ml beer × 90% = 297 ml water
is not a reviewed recipe estimate. Do not infer water fraction as 1 − ABV.

All 60 definitions now have approved generic water estimates. Fifty-two use a
fixed fraction across their supported preparations; eight Alcohol definitions
use reviewed ABV lookup tables with separate non-alcoholic estimates where offered.
The exact fractions and recipe limitations are recorded in the catalogue contract.
These are estimates, not measured universal composition or market averages.

Capture a separate optional `waterAmount` in millilitres in each new snapshot.
Unknown remains supported and distinct from zero. Existing saved facts stay
unchanged; older records without water remain unknown. No backfill or reset.

See [catalogue contract](../Drink-Catalogue-Files.md#water-content-structure--10-november-2026-95-106):
content development-25, schema 6, calculation 5; legacy schemas 1–5 remain readable.

## Eligibility matrix and validation

The following covers all 60 reviewed definitions. “Eligible” means that a supported
saved positive quantity may produce a sample after opt-in and type authorization;
it does not infer eligibility from a category or the current mutable catalogue.
Older snapshots with missing quantities remain unknown. Recipe scope/exclusions
are in the [catalogue contract](../Drink-Catalogue-Files.md).

| Category (entries) | Water | Caffeine | Alcohol count |
| --- | --- | --- | --- |
| Water (4) | Saved water eligible | Known zero; omit | No captured exact positive ABV; omit |
| Coffee (7) | Saved water eligible | Positive saved regular/decaf estimate eligible; zero-shot zero omitted | Omit |
| Tea (10) | Saved water eligible | Positive saved estimate eligible; caffeine-free/known zero omitted | Omit |
| Juices (4) | Saved water eligible | Known zero; omit | Omit |
| Soft Drinks (6) | Saved water eligible | Regular Cola positive; caffeine-free Cola and other five zero | Omit |
| Wellness (3) | Saved water eligible | Kombucha positive; other two zero | Kombucha unknown; omit |
| Sports & Energy (4) | Saved water eligible | Energy drink positive; other three zero | Omit |
| Milk & Alternatives (12) | Saved water eligible | Chocolate milk/Hot chocolate positive; other ten zero | Omit |
| Alcohol (8) | Saved selected-strength/preparation water eligible | Cocktail/Liqueur unknown; other six zero | Exact saved positive ABV eligible; non-alcoholic upper-bound-only omitted |
| Other (2) | Saved water eligible | Known zero; omit | Omit |

Map `waterAmount` directly to dietaryWater in ml and `caffeineAmount` directly to
dietaryCaffeine in mg. Positive finite quantities are eligible; zero means no sample,
nil means unknown/no sample, negative or non-finite values are invalid/no sample.
Water must not exceed valid consumed volume. Alcohol uses the approved conversion
below. Invalidity of one quantity must not suppress otherwise valid independent
types; invalid logged time prevents all sample construction for that entry.
Reject invalid/nonpositive/non-finite consumed volume and invalid dates explicitly.
Unknown or negative hydration-goal credit is never a reason to change an otherwise
valid saved water/caffeine quantity. No sample is inferred from a missing recipe.

Sugar, calories, protein, CBD and other nutrition types are excluded. No general
HealthKit reads/import, goal calculations or historical quantity reconstruction.
Retirement, renaming and new recipes do not alter captured export facts. Older
snapshots with no exact ABV cannot distinguish known alcohol-free from unknown;
both omit alcohol, without inventing a zero value.

## Worked mapping examples

Values below assume authorized types and a valid `loggedAt`. Rounded counts are
for reading only; export retains full precision. “Omit” does not write a zero sample.

| Saved facts | Water sample | Caffeine sample | Alcohol-count sample |
| --- | ---: | ---: | ---: |
| Still water, 330 ml | 330 ml | Omit (zero) | Omit |
| Latte, 250 ml, 2 regular shots | 225 ml | 120 mg | Omit |
| Latte, 250 ml, 2 decaf shots | 225 ml | 10 mg | Omit |
| Beer, 330 ml, 5% ABV; goal credit zero | 306.9 ml | Omit (zero) | 0.929893 |
| Non-alcoholic beer, 330 ml, exact ABV unknown ≤0.5% | 320.1 ml | Omit (zero) | Omit (unknown) |
| Cocktail, 200 ml, 10% ABV | 170 ml | Omit (unknown) | 1.127143 |
| Synthetic historical snapshot: water nil, caffeine 60 mg, ABV nil, goal credit unknown | Omit (unknown) | 60 mg | Omit (unknown) |
| Synthetic historical snapshot: water/caffeine/ABV nil, goal credit −20 ml | Omit | Omit | Omit |
| Synthetic saved facts: water 170 ml, caffeine 40 mg, 200 ml at 10% ABV | 170 ml | 40 mg | 1.127143 |

The final fixture illustrates independent three-type mapping, not a new approved
catalogue recipe. All actual recipes must stay within reviewed scope.

Supported input units are ml, US fl oz and Imperial fl oz. For example, an 8 US fl oz
5% beer is 236.5882365 ml; 8 Imperial fl oz is 227.3045 ml. At the reviewed 93% water
fraction, capture `volumeMl × 0.93`; alcohol count is `volumeMl × 0.05 × 0.789 / 14`.
Use Foundation physical-volume conversion without rounding either stage. Later
unit-display changes leave the saved quantities unchanged.

For `loggedAt = 2026-11-14T20:00:00Z`, both start and end are that same instant,
including when displayed as 21:00 in Madrid or retried later. Neither `createdAt`
nor export time substitutes for it. NaN/infinite dates are rejected. A manually
logged entry stays manual (`HKMetadataKeyWasUserEntered = true` at the future
sample boundary); export does not become a new provenance source.

## Approved platform mapping

Apple defines [dietaryWater](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/dietarywater)
as consumed-water volume and [dietaryCaffeine](https://developer.apple.com/documentation/HealthKit/HKQuantityTypeIdentifier/dietaryCaffeine)
as consumed-caffeine mass. These definitions do not validate a generic recipe
estimate or provide beverage-specific water fractions.

The agreed caffeine direction remains positive saved mass; known zero emits no
sample and unknown remains unknown. Regular/decaf and shot-based versus volume-based
calculations are already captured when logging; export must not recompute them.
The agreed date direction remains start = end = saved `loggedAt`, rejecting invalid
dates rather than substituting creation/export time. [HKSample](https://developer.apple.com/documentation/healthkit/hksample)
supports point-in-time samples with equal start/end dates.

### Alcohol conversion approved 14 November 2026

Frank approved alcohol-count export alongside water and caffeine. Use Apple's
[numberOfAlcoholicBeverages](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/numberofalcoholicbeverages)
with `HKUnit.count()` and fractional quantities. Apple documents standard drinks
but does not specify a grams-per-drink conversion in that API documentation.
Watered explicitly adopts the [NIAAA 14 g convention](https://www.niaaa.nih.gov/alcohols-effects-health/what-standard-drink),
with approximate ethanol density 0.789 g/ml. This is a Watered policy choice,
not a verified Apple-mandated or locale-specific definition.

`standardDrinks = savedVolumeMl × savedABVFraction × 0.789 / 14`

| Saved drink | Alcohol mass (g) | Standard-drink count (display approximation) |
| --- | ---: | ---: |
| Beer, 330 ml at 5% | 13.0185 | 0.929893 |
| Wine, 175 ml at 13% | 17.94975 | 1.282125 |
| Spirits, 25 ml at 40% | 7.89 | 0.563571 |
| Cocktail, 200 ml at 10% | 15.78 | 1.127143 |

Export the full calculated precision, not the rounded table values or one count
per container. Convert US/Imperial fluid ounces to ml before calculation. Use
only captured volume and exact ABV; no current catalogue or category lookup.
Known zero emits no sample. Missing exact ABV and upper-bound-only preparations
emit no alcohol sample and remain unknown, including Kombucha and the current
non-alcoholic options up to 0.5%. Never substitute that maximum or zero. Non-finite,
nonpositive volume, out-of-range ABV, or contradictory exact/bounded facts are
invalid and produce no quantity. Invalid input is distinct from unknown.

Water and caffeine eligibility remain independent of alcohol. Use saved `loggedAt`
for both sample dates; reject invalid dates rather than substituting export time.
Keep manual provenance. Write authorization scope now includes alcohol count;
no read/import access is approved. Permission UI and actual writes remain #107.

[AlcoholExportQuantity](../../Watered/Watered/HealthExport/AlcoholExportQuantity.swift)
implements only this pure quantity conversion with policy `alcohol-14g-v1` and
explicit positive/known-zero/unknown/invalid results. It does not construct samples
or validate sample dates. The future mapper must validate dates independently.
#96/#108 must persist the chosen policy with pending export work so upgrades and
retries cannot silently reinterpret quantities; this constant alone does not
implement durable retry/version context. No historical re-export is implied.

[Authorization request completion](https://developer.apple.com/documentation/healthkit/hkhealthstore/requestauthorization(toshare:read:completion:))
is not proof of permission. Request only reviewed write types, no general read/import
access. Manual provenance stays manual; [WasUserEntered](https://developer.apple.com/documentation/healthkit/hkmetadatakeywasuserentered)
can represent this at the platform boundary. Apple sources were reviewed on 10 November 2026.

## Implementation and verification

[WaterContent](../../Watered/Watered/Models/WaterContent.swift) decodes the explicit
content object; catalogue validation also checks programmatic fractions. The
[calculator](../../Watered/Watered/Catalogue/DrinkEstimateCalculator.swift) uses
unrounded physical volume. The resolver captures the resulting millilitres;
[PersistentDrinkEntry](../../Watered/Watered/Persistence/PersistentDrinkEntry.swift)
stores/restores that value without a catalogue lookup. Repeating a recent drink
creates a new event using current rules; it never changes its source entry.

[Regression coverage](../../Watered/WateredTests/WaterContentTests.swift) covers
reviewed catalogue membership and preparation-specific water, strict schema decoding, older schema fallback,
invalid values, all three units, zero versus unknown, disk save/dispose/reopen,
current-rule repeats and retained historical snapshots. Hosted CI execution is
verified by the [catalogue unit run](https://github.com/franksedivy/watered-ios/actions/runs/42910205501)
for `9881bad`. Alcohol conversion tests passed in the [conversion unit run](https://github.com/franksedivy/watered-ios/actions/runs/43632446726)
for `a299568`. Hosted environment: Xcode 27.1, iPhone Air/iOS 27.0; WateredTests only,
UI suites excluded. Frank confirmed the suggested manual logging/strength/repeat/
relaunch checks on 14 November; this is not physical-device HealthKit verification.
At that evidence checkpoint, implementation was pushed on `feature/95-healthkit-mapping`
and was not yet merged. It subsequently merged in PR #164; no release is implied.

## Original implementation handoffs

- #95: policy, eligibility matrix, examples and implementation handoff complete on 14 November 2026. This closes the decision task, not the integration.
- #108: map captured water, caffeine and alcohol quantities independently using this approved policy. Preserve quantities through catalogue retirement, display-unit changes and retries. Add explicit immutable export-policy context in coordination with #96; catalogue/calculation versions are not export-policy versions.
- #96: retain ownership of opt-in/backfill, durable per-type states, retries, deduplication, partial success and deletion. Any reconciliation of Watered-owned samples needs narrow justification. This change makes none of those choices.
- #107/#111: reviewed write types, independent permissions and honest estimate wording. No HealthKit client or permission changes in this slice.
- #112: mapping, persistence and controlled-device verification. Test zero/one/two/three-type outcomes and independent permission combinations, without personal Health data in routine automation.

No HealthKit writes, historical re-export, PR, merge or release is authorized by
this record. All catalogue water estimates have been reviewed.

Alcohol water uses schema 6 reviewed tables for every supported ABV and a separate
non-alcoholic fraction where offered. Calculation version 5 resolves the selected
preparation before saving water; no historical amounts are recalculated.
