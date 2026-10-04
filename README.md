# Watered
The hydration tracker Apple forgot. Realistic drink textures and playful fluid dynamics make every pour feel alive, with a vision for hydration goals shaped around your climate, health, and training. Private by design. Delightful by nature.

## Current Status
`0.4 Persistence & Analytics` is complete. Drink logging, Today summaries, recent-drink shortcuts, and drink deletion are implemented. SwiftData stores drinks, display units, the current hydration goal, and goal-change history locally. Analytics events are logged locally in Debug builds and discarded in Release builds.

The current focus is `0.5 Drink Catalogue & HealthKit syncing`: a scalable catalogue of 50-60 built-in drinks, optional export-only HealthKit integration, and focused refactoring of persistence responsibilities out of the app's navigation view. Existing drink history must remain compatible as the catalogue expands.

HealthKit is planned, not yet implemented; reading or importing HealthKit data is outside the initial scope. Widgets, a Watch app, iCloud sync, and production analytics collection remain future work.

## Getting Started
Requires Xcode 27 or later and an iOS 27 or later simulator or device.

1. Open `Watered/Watered.xcodeproj` in Xcode.
2. Select the `Watered` scheme to build and run.
3. Use Product > Test to run the test suite.

## Contributing
Changes are managed through pull requests.
- Create a focused branch from `main`.
- Keep each PR scoped to one ticket or a small, coherent change.
- Reference the relevant GitHub issue.
- Summarise what changed and how it was tested.
- Include screenshots or recordings for visible UI changes.
- Review the diff and run relevant tests before merging.
- Keep `main` ready to build and run.

Update documentation alongside behaviour or architecture changes.
## Project Principles
Model-first, small commits, tests, clean separation of concerns.

## Documentation
Implementation details and decisions live in the wiki:
- [Architecture Overview](https://github.com/franksedivy/watered/wiki/Architecture-Overview)
- [Decision Log](https://github.com/franksedivy/watered/wiki/Decision-Log)
- [Persistence](https://github.com/franksedivy/watered/wiki/Persistence)
- [Drink Types & Contributions](https://github.com/franksedivy/watered/wiki/Drink-Types-And-Contributions)
- [Hydration Model](https://github.com/franksedivy/watered/wiki/Hydration-Model)
- [Research Notes](https://github.com/franksedivy/watered/wiki/Research-Notes)
- [Testing Approach](https://github.com/franksedivy/watered/wiki/Testing-Approach)

You can also read about the overall progress in my [Design Engineer's diary](https://github.com/franksedivy/watered/wiki/Design-Engineer's-Diary).

## Current Milestones & Releases
- `0.1` [Core-model](https://github.com/franksedivy/watered/milestone/1), [Release notes](https://github.com/franksedivy/watered/releases/tag/0.1_Core-model)
- `0.2` [Basic Today UI](https://github.com/franksedivy/watered/milestone/2), [Release notes](https://github.com/franksedivy/watered/releases/tag/0.2_Today-UI)
- `0.3` [Add Drink Flow](https://github.com/franksedivy/watered/milestone/3), [Release notes](https://github.com/franksedivy/watered/releases/tag/0.3_Add-drink)
- `0.4` [Persistence & Analytics](https://github.com/franksedivy/watered/milestone/4), [Release notes](https://github.com/franksedivy/watered-ios/releases/tag/0.4_Persistence-and-analytics)
- `0.5` [Drink Catalogue & HealthKit syncing](https://github.com/franksedivy/watered/milestone/5)
- `0.6` [iOS Widget](https://github.com/franksedivy/watered/milestone/6)
- `0.7` [Watch App](https://github.com/franksedivy/watered/milestone/7)
- `0.8` [Polish And App Foundations](https://github.com/franksedivy/watered/milestone/8)
- `0.9` [Detailed UI pass](https://github.com/franksedivy/watered/milestone/9)
- `1.0` [Launch](https://github.com/franksedivy/watered/milestone/10)
