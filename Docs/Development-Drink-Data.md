# Development Drink Data

Drink entries now require a captured catalogue snapshot. The original enum-based
development drinks are not migrated or given invented estimates.

These instructions apply only to the old enum-only development rows, not to
snapshot-backed stores or routine 0.5 upgrades. If that old history is disposable
and you explicitly choose to remove it, open Profile in a Debug build and confirm
**Delete all drinks**. Display-unit settings, the hydration goal and goal-change
history remain saved. Never delete history as an automatic upgrade step.

If the updated build is already running, the same Profile action can clear the old
rows. Unreadable rows are reported in the persistence log and remain stored until
explicitly deleted. The app does not reset its database automatically. For drinks
with possible Health exports, deletion hides the drink and retains its details until
the required cleanup is acknowledged; it need not immediately purge every row.

New snapshot-backed entries remain readable even when their drink is removed or
retired from the catalogue. Recents lists only preparations supported by the current
catalogue, and repeating one resolves fresh estimates for the new entry.
