# 001 — Capture water content independently of hydration credit

- Status: Structure and quantity direction accepted by Frank on 10 November 2026. All catalogue water estimates are approved; final export mapping remains under review.
- Owner/reviewer: Frank Sedivy.
- Related: [#95](https://github.com/franksedivy/watered-ios/issues/95), parent [#106](https://github.com/franksedivy/watered-ios/issues/106), mapping [#108](https://github.com/franksedivy/watered-ios/issues/108).
- Supersedes: the narrow Still/Sparkling/Infused-only water policy approved earlier in this chat. The subsequent full-beverage-volume suggestion was also rejected.

## Context and decision

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

## Platform facts and remaining mapping decisions

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

Alcohol export is now a requested direction for review. Apple's
[numberOfAlcoholicBeverages](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/numberofalcoholicbeverages)
uses standard-drink counts, not ethanol millilitres/grams. Its conversion and
permission scope require an explicit decision before implementation. No such
conversion or authorization change is included here.

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
reported in #95; this document does not claim a pass before one exists.

## Outstanding handoffs

- #95: all 60 water estimates are reviewed. Finalize the export mapping and examples; catalogue delivery alone does not close #95.
- #108: map supported captured water/caffeine quantities independently after policy review. Preserve quantities through catalogue retirement, display-unit changes and retries. Add explicit immutable export-policy context in coordination with #96; catalogue/calculation versions are not export-policy versions.
- #96: retain ownership of opt-in/backfill, durable per-type states, retries, deduplication, partial success and deletion. Any reconciliation of Watered-owned samples needs narrow justification. This change makes none of those choices.
- #107/#111: reviewed write types, independent permissions and honest estimate wording. No HealthKit client or permission changes in this slice.
- #112: mapping, persistence and controlled-device verification. Test neither/one/both outcomes once recipe water values are reviewed, without personal Health data in routine automation.

No HealthKit writes, historical re-export, PR, merge or release is authorized by
this record. All catalogue water estimates have been reviewed.

Alcohol water uses schema 6 reviewed tables for every supported ABV and a separate
non-alcoholic fraction where offered. Calculation version 5 resolves the selected
preparation before saving water; no historical amounts are recalculated.
