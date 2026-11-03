# Add Drink category prototype (#104)

The sheet opens with a neutral category row and the volume wheel visible. Recent
drinks are temporarily hidden, without changing stored history or recent-drink
calculation. Selecting a category raises the sheet and reveals a separate row of
illustrated drink cards directly below it. Volume stays visible and unchanged.

Selecting Water highlights Still water; selecting Coffee highlights Latte.
The highlighted card is the actual drink saved, so category + volume + Save is
sufficient. A card tap refines the choice. Tapping the active category preserves
that choice; switching categories starts with the new category's default. Defaults
are UI-only prototype choices, not a change to catalogue data or last-used rules.
If a preferred drink is unavailable, the first active drink is used.

Preparation controls, when the selected drink supports them, sit behind a
Preparation disclosure. Opening it raises the sheet to full height. Accessibility
text sizes also use full height, and Reduce Motion suppresses content animation.

Only Water and Coffee exist in the current bundled catalogue. Tea and Juice are
not invented for this prototype. Drink thumbnails are provisional SwiftUI drawings,
not the reference photography. The existing system volume wheel and sheet material
are retained; realistic liquid fills and time editing remain separate work.

## Verification

No UI tests were added or run for this prototype. The existing recent-shortcut UI
test still describes the old visible-recents behavior and will need revision when
the interaction is settled. This prototype commit skips the automatic CI suite.
Focused unit tests cover preferred IDs, retired/default fallback, empty categories,
and future categories. They have not been executed here. An Xcode build and
physical/simulator visual review are still required; the editing
environment has no Apple toolchain.

Manual review: open from empty and populated histories; select Water and save
without a card tap; select Coffee; refine a drink; re-tap its category; switch
categories after changing volume; dismiss and reopen; retry a failed save; check
large text and manual sheet dragging. Verify that the volume never resets during
selection and the saved drink matches the highlighted card.
