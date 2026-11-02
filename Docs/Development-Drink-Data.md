# Development Drink Data

Drink entries now require a captured catalogue snapshot. The original enum-based
development drinks are not migrated or given invented estimates.

Before using the updated app, open Profile in the existing Debug build and confirm
**Delete all drinks**. Then install/run the updated build. This clears drink history
only; display-unit settings, the hydration goal and goal-change history remain saved.

If the updated build is already running, the same Profile action can clear the old
rows. Unreadable rows are reported in the persistence log and remain stored until
explicitly deleted. The app does not reset its database automatically.

New snapshot-backed entries remain readable even when their drink is removed or
retired from the catalogue. Recents lists only preparations supported by the current
catalogue, and repeating one resolves fresh estimates for the new entry.
