# Add Drink interaction (#104)

## Current behaviour

A fresh sheet starts with no category selected and Save disabled. Selecting Water
chooses Still water; selecting Coffee chooses Latte. If a preferred drink is not
available, the first active drink is selected. Tapping the current category preserves
its selection. Changing categories or drink types preserves explicitly chosen/restored volume and resets
preparation to the selected definition's defaults. Persistent last-used choices per
category are not implemented in this slice.

Drinks use bundled PNG artwork named by catalogue ID where available, rendered
in original colours with aspect-fit sizing. Missing artwork uses the illustrative
fallback. The selected card uses a category-colored border without a tick overlay.

Preparation is visible beneath the drink cards. All seven coffees offer regular /
decaf; Latte, Cappuccino, Espresso, Americano and Iced coffee also offer 0–4 shots.
Espresso and Cappuccino default to one; the others default to two. Shots never resize
the drink or change its hydration ratio. Caffeine uses the reviewed per-shot or
per-volume defaults in [Drink Catalogue Files](Drink-Catalogue-Files.md). The decaf icon changes from bolt to bolt.slash; preparation
icons are brown. Milk options, time editing and a liquid-filled wheel are deferred.

The clipped volume wheel is anchored to the sheet's bottom safe area, outside the
scrolling drink/preparation content. Its background remains transparent so the
sheet's glass material continues behind the picker. Changing drinks, preparation controls or sheet
height leaves the picker in the same bottom position; extra content grows above it
and scrolls independently. The sheet starts at 480 points to fit the fixed picker
and category row, expands to 600 without preparation or 720 with it, and allows
manual full-height expansion. Accessibility text sizes use full height; Reduce
Motion suppresses the selection animation. Small screens may require scrolling the
upper content; the picker stays available.

## Unsaved session draft

Dismissing retains category, drink, preparation and volume including its unit.
Reopening restores the draft and an appropriate sheet height. A successful save
(including a recent shortcut) clears it; failed saves preserve it. App restart
clears it. Fresh and restored forms display the applied Profile unit. A restored draft
retains its exact captured amount and preparation; conversion affects presentation
only. Non-preset converted amounts get their own wheel option. The picker and recent
menu round millilitres to whole numbers (12 US fl oz displays as 355 ml); fluid
ounces use up to three decimal places. Display rounding is never saved. Selecting a different preset
replaces the amount in the current display unit. Repeated unit changes cannot
accumulate rounding loss. Failed Profile persistence leaves the applied unit unchanged.
This replaces the earlier neutral-on-every-open rule. It is distinct from persistent
per-category last-used preferences, which remain deferred.

## Recent drinks

Touch and hold Add Drink to show up to three supported distinct shortcuts. An empty
history shows a disabled “No recent drinks yet” item. Selecting a shortcut logs a
fresh entry using the saved preparation and current catalogue rules without opening
the sheet. Missing/retired drinks and unsupported preparations are excluded.

Local persistence succeeds before history or success analytics change. A menu save
failure shows an alert outside the sheet. Existing submission-boundary tests cover
recent success/failure and analytics isolation. Shortcut labels use the applied
Profile unit through the shared volume formatter. Repeating retains the original
amount and preparation; display conversion does not change shortcut identity,
deduplication or historical entries.

## Verification

The #133 tests cover all source/display unit pairs, fresh/restored forms, converted
non-preset amounts, preset changes, retained preparation, recent repetition and
failed drink/settings saves. Screenshots are attached by the converted-draft and
recent-menu UI tests. Hosted results must establish that these checks passed.

The #104 candidate adds catalogue/schema, zero-shot calculation/persistence, preparation,
draft restoration/clearing, failure-retry and restart coverage. UI coverage follows
the long-press Recents interaction. The #138 millilitres test is re-enabled. Hosted
CI results must be recorded against the exact commit; added tests are not evidence
that they passed. The configured plan still excludes launch-performance tests.

Frank reviewed the artwork, preparation panel and sheet heights in the simulator.
Physical-device checks, VoiceOver, large Dynamic Type, dark appearance, Reduce Motion,
and long-press menu failure presentation remain manual verification items. No release
or complete #104 acceptance is implied by this document.


Plain tea (#101) uses the standard SwiftUI `.mint` category tint and catalogue serving defaults of 250 ml while the volume remains
untouched. Deliberate volume choices and restored drafts take precedence. Black,
Green and White offer regular/decaf; Herbal has no preparation controls. See
[reviewed tea defaults](Drink-Catalogue-Files.md#plain-tea--approved-8-november-2026-101--102).

Selected drink image tiles use a 2-point category-color border over the neutral
background: blue for Water, brown for Coffee and system mint for Tea. Category
pills retain their colored fill when selected. Drink names use the standard primary
text color (black in light mode), independently of category tint.
