# Watered
The hydration tracker Apple forgot. Realistic drink textures and playful fluid dynamics make every pour feel alive, with a vision for hydration goals shaped around your climate, health, and training. Private by design. Delightful by nature.

## Current Status

The `0.5 Drink Catalogue & Apple Health` implementation is complete and under final release review. It includes 60 built-in drinks across ten categories, preparation choices, serving suggestions and optional one-way export of water, caffeine and alcohol estimates to Apple Health. Local logging works without Health permission.

SwiftData stores drink history, display units, the hydration goal and goal changes locally. Saved drinks retain their captured catalogue facts; repeating an available recent drink uses current rules. Health export uses independent per-type permission, frozen quantities, durable retries and scoped deletion cleanup. Existing history is not automatically exported. Debug analytics stay local; Release discards events.

The standards audit is complete. The audited candidate passed 336 hosted unit tests; hosted UI is excluded. All 53 configured UI tests also passed locally at normal text size on the iPhone Air simulator. The tested revision matches the merged candidate tree. The final Release smoke test passed on a physical iPhone Air. Add Drink's larger-text clipping and remaining visual refinement are explicitly deferred. See the [draft release notes](Docs/releases/0.5-release-notes.md) and [release evidence](Docs/releases/0.5-evidence.md) for scope, accepted limitations and remaining release checks. No publication or release approval is implied.

Health import, iCloud sync, remote catalogue delivery, widgets, a Watch app and production analytics collection remain outside this release. See [Development Drink Data](Docs/Development-Drink-Data.md) for the older enum-only development-store boundary; history is never automatically erased.

## Getting Started
Requires Xcode 27 or later and an iOS 27 or later simulator or device.

1. Open `Watered/Watered.xcodeproj` in Xcode.
2. Select the `Watered` scheme to build and run.
3. Use Product > Test to run the test suite.

## Automated Tests
GitHub Actions runs unit tests on branch pushes, using a hosted iOS
simulator rather than local simulators. See [Continuous Integration](Docs/Continuous-Integration.md)
for the pinned toolchain, manual runs, test-result artifacts and coverage limits.

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

See the [project principles](Docs/PRINCIPLES.md) for their rationale, product principles and applications of Apple’s design principles.

## Documentation

Repository guidance:
- [Project principles](Docs/PRINCIPLES.md)
- [Agent guidance](AGENTS.md)
- [Contributing](CONTRIBUTING.md)
- [Architecture](Docs/ARCHITECTURE.md)
- [Testing](Docs/TESTING.md) and [Continuous Integration](Docs/Continuous-Integration.md)
- [Releasing](Docs/RELEASING.md)
- [Decision-record template](Docs/decisions/TEMPLATE.md) and [handoff template](Docs/handoffs/TEMPLATE.md)

The wiki explains how the app works, with a complete drink reference, calculations, research and decisions. Repository guidance owns implementation details, development workflow and recorded verification.

- [Architecture Overview](https://github.com/franksedivy/watered-ios/wiki/Architecture-Overview)
- [Decision Log](https://github.com/franksedivy/watered-ios/wiki/Decision-Log)
- [Persistence](https://github.com/franksedivy/watered-ios/wiki/Persistence)
- [Drink Types & Contributions](https://github.com/franksedivy/watered-ios/wiki/Drink-Types-And-Contributions)
- [Hydration Model](https://github.com/franksedivy/watered-ios/wiki/Hydration-Model)
- [Research Notes](https://github.com/franksedivy/watered-ios/wiki/Research-Notes)
- [Testing Approach](https://github.com/franksedivy/watered-ios/wiki/Testing-Approach)

You can also read about the overall progress in my [Design Engineer's diary](https://github.com/franksedivy/watered-ios/wiki/Design-Engineer's-Diary).

## Current Milestones & Releases
- `0.1` [Core-model](https://github.com/franksedivy/watered/milestone/1), [Release notes](https://github.com/franksedivy/watered/releases/tag/0.1_Core-model)
- `0.2` [Basic Today UI](https://github.com/franksedivy/watered/milestone/2), [Release notes](https://github.com/franksedivy/watered/releases/tag/0.2_Today-UI)
- `0.3` [Add Drink Flow](https://github.com/franksedivy/watered/milestone/3), [Release notes](https://github.com/franksedivy/watered/releases/tag/0.3_Add-drink)
- `0.4` [Persistence & Analytics](https://github.com/franksedivy/watered/milestone/4), [Release notes](https://github.com/franksedivy/watered-ios/releases/tag/0.4_Persistence-and-analytics)
- `0.5` [Drink Catalogue & HealthKit syncing](https://github.com/franksedivy/watered-ios/milestone/5) — [draft release notes](Docs/releases/0.5-release-notes.md)
- `0.6` [iOS Widget](https://github.com/franksedivy/watered/milestone/6)
- `0.7` [Watch App](https://github.com/franksedivy/watered/milestone/7)
- `0.8` [Polish And App Foundations](https://github.com/franksedivy/watered/milestone/8)
- `0.9` [Detailed UI pass](https://github.com/franksedivy/watered/milestone/9)
- `1.0` [Launch](https://github.com/franksedivy/watered/milestone/10)
