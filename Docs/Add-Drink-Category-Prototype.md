# Add Drink interaction (#104)

## Current behaviour

A fresh sheet starts with no category selected and Save disabled. Selecting Water
chooses Still water; selecting Coffee chooses Latte. If a preferred drink is not
available, the first active drink is selected. Tapping the current category preserves
its selection. Changing categories or drink types preserves volume and resets
preparation to the selected definition's defaults. Persistent last-used choices per
category are not implemented in this slice.

The eleven current drinks use bundled PNG artwork named by catalogue ID, rendered
in original colours with aspect-fit sizing. Missing artwork uses the illustrative
fallback. The selected card uses the category colour without a tick overlay.

Preparation is visible beneath the drink cards. All seven coffees offer regular /
decaf; Latte, Cappuccino, Espresso and Americano also offer 0–4 shots, defaulting to
2. Shots never resize the drink. Caffeine estimates remain unknown, including decaf
and zero-shot choices. The decaf icon changes from bolt to bolt.slash; preparation
icons are brown. Milk options, time editing and a liquid-filled wheel are deferred.

The clipped volume wheel, cards and preparation share one vertical scroll layout.
The sheet starts at 440 points, expands to 600 without preparation or 720 with it,
and allows manual full-height expansion. Accessibility text sizes use full height;
Reduce Motion suppresses the selection animation. Small screens may require scrolling.

## Unsaved session draft

Dismissing retains category, drink, preparation and volume including its unit.
Reopening restores the draft and an appropriate sheet height. A successful save
(including a recent shortcut) clears it; failed saves preserve it. App restart
clears it. Profile unit changes do not reinterpret the unfinished amount: the
restored draft keeps its captured unit, while a fresh form uses the current setting.
This replaces the earlier neutral-on-every-open rule. It is distinct from persistent
per-category last-used preferences, which remain deferred.

## Recent drinks

Touch and hold Add Drink to show up to three supported distinct shortcuts. An empty
history shows a disabled “No recent drinks yet” item. Selecting a shortcut logs a
fresh entry using the saved preparation and current catalogue rules without opening
the sheet. Missing/retired drinks and unsupported preparations are excluded.

Local persistence succeeds before history or success analytics change. A menu save
failure shows an alert outside the sheet. Existing submission-boundary tests cover
recent success/failure and analytics isolation. Shortcut labels still use the logged
unit; current-display-unit formatting remains #133.

## Verification

The candidate adds catalogue/schema, zero-shot calculation/persistence, preparation,
draft restoration/clearing, failure-retry and restart coverage. UI coverage follows
the long-press Recents interaction. The #138 millilitres test is re-enabled. Hosted
CI results must be recorded against the exact commit; added tests are not evidence
that they passed. The configured plan still excludes launch-performance tests.

Frank reviewed the artwork, preparation panel and sheet heights in the simulator.
Physical-device checks, VoiceOver, large Dynamic Type, dark appearance, Reduce Motion,
and long-press menu failure presentation remain manual verification items. No release
or complete #104 acceptance is implied by this document.
