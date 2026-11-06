# Watered principles

Agreed on 6 November 2026. This document explains how we make product, design and engineering decisions. Workflow steps belong in [Contributing](../CONTRIBUTING.md), agent instructions in the [agent guidance](../AGENTS.md), and implementation details in [Architecture](ARCHITECTURE.md).

## Where these principles come from

**Original foundations:** the README names model-first thinking, small commits, tests and separation of concerns. The early Design Engineer's Diary describes building the smallest useful model, learning through tests and Frank writing code with guidance.

**Practices developed during the project:** the wiki records offline logging, native foundations, honest estimates, preserved history and privacy. Later diary reflections explain why prototypes still need understandable structure.

**Agreed wording:** the explanations and examples below consolidate those sources. Frank suggested the Apple design framework; its Watered applications guide decisions but are not claims of implemented features or quotations from Apple.

## Product principles

### Keep everyday logging dependable

Logging and saved history should work offline. Optional integrations must not make local saving depend on network access or health permissions. Save successfully before presenting an action as complete; when saving fails, preserve the person's work and support retry.

### Respect personal data

Keep collection purposeful and limited. Product analytics should describe interactions without reconstructing someone's drink history. A future integration or analytics provider needs an explicit decision about what it collects and why; existing local storage is not blanket permission for new collection.

### Be honest about what we know

Distinguish recorded amounts, estimated hydration effects, recommendations and unknown values. More decimal places do not make an estimate more certain. Show uncertainty honestly and keep assumptions traceable. Unknown is not the same as zero.

### Preserve what was recorded

A logged drink retains the facts and estimates captured at the time. New catalogue definitions must not silently reinterpret history. Changing display units changes presentation; repeating a drink creates a new event under current rules. Data deletion should be an explicit action, not a hidden recovery mechanism.

## Design principles

Use [Apple's Human Interface Guidelines: Design principles](https://developer.apple.com/design/human-interface-guidelines/design-principles) as a shared reference. We apply them to Watered as follows:

| Apple principle | Application to Watered |
| --- | --- |
| Purpose | Prioritise logging a drink and understanding today's progress. Evaluate additions against those needs. |
| Agency | Let people choose amounts and goals, dismiss flows and recover from mistakes. Preserve selections after a failed save. |
| Responsibility | Explain estimates and permissions clearly; protect personal history. |
| Familiarity | Start with native navigation, sheets and controls. Custom interactions need a clear product benefit. |
| Flexibility | Design for large text, VoiceOver, Reduce Motion and different units; preserve context as layouts adapt. |
| Simplicity | Keep frequent actions easy to reach. Reveal preparation details when relevant and use concise labels. |
| Craft | Refine wording, layout, feedback and performance together. Review interactions on a device as well as in code. |
| Delight | Use playful liquid imagery and motion to make logging satisfying without delaying it or obscuring information. |

These principles guide tradeoffs rather than mandate a particular visual style. Native foundations leave room for Watered's character. Accessibility and dependable behaviour remain part of the design when exploring that character.

## Engineering principles

### Model the behaviour before wiring the interface

Define the amounts, identities, rules and outcomes needed for the current feature. Make them understandable and testable independently of a screen. This is the project's model-first approach: start with the smallest useful model, not a complete speculative architecture. Interaction prototypes can inform and change the model.

### Give each part a clear responsibility

The established shorthand is: **models calculate, snapshots summarise, view data prepares, views display.** Persistence owns storage operations; the app shell coordinates navigation and actions. Keep business rules out of view layout and formatting out of storage records.

Here, “snapshots summarise” refers to derived hydration summaries. A saved catalogue snapshot has a different job: preserving captured drink facts. Keep that distinction clear in names and explanations.

### Prefer platform foundations and simple structures

Use SwiftUI, system controls and Foundation types where they fit. The early move from handwritten conversion constants to `Measurement<UnitVolume>` is a useful example. Add abstractions when a concrete responsibility or repeated need justifies them. Apply separation of concerns without turning every small feature into a framework.

### Measure before optimising

Use observed behaviour to identify performance problems and verify improvements. Check launch responsiveness, scrolling and animation on representative devices. Establish a baseline, investigate the cause and compare the result under the same conditions. Avoid speculative micro-optimisations and do not hide failed operations behind success feedback.

### Compose small, focused parts

Build behaviour from small collaborating types and views rather than deep inheritance hierarchies. Introduce protocols where substitution or testing needs them, and abstractions where they solve a demonstrated problem. Separate feature modules are an option when build times or ownership justify their maintenance cost, not a prerequisite for clear boundaries.

### Prove meaningful behaviour

Tests should help explain what the system promises: conversions, calculations, historical meaning, persistence and failure recovery. Use test-first work when it helps clarify a rule. Visual and interaction checks complement automated tests. Report exactly what was verified; a build, focused test and device review provide different evidence.

### Make small changes without sacrificing structure

Keep changes coherent enough to understand, review and verify. Temporary behaviour may be discarded, but a prototype still needs clear ownership and readable code. Avoid letting a single view absorb unrelated responsibilities just because the design is exploratory. Refactor where the current change exposes a concrete problem.

### Keep the work understandable to its owner

Learning and personal ownership were part of the original project. In guided sessions, Frank takes one explained step at a time and reviews the result. Delegated implementation is also valid when requested; it should still leave code and decisions he can understand and maintain. The original read-only tutoring arrangement is historical context, not a permanent ban on explicitly requested implementation.

## Using and revising these principles

Use them to explain a decision in a review: which principle matters, what tradeoff exists and why the chosen approach fits. When principles compete, prefer the smallest change that preserves trust and dependable core behaviour, then test the design with the relevant evidence.

Principles can evolve through an explicit decision. Record consequential exceptions or changes in the agreed decision log, rather than quietly weakening them in individual implementations. Keep release scope and task status in GitHub.

## Source notes

Reviewed the local `watered-wiki` checkout at `982cc36`; it was not refreshed from the remote. These sources establish project intent and history, not current release readiness:

- [README project principles](../README.md#project-principles).
- [Design Engineer's Diary](https://github.com/franksedivy/watered/wiki/Design-Engineer's-Diary): early model-first and learning approach; later prototype and native-platform lessons.
- [Architecture Overview](https://github.com/franksedivy/watered/wiki/Architecture-Overview): local-first, responsibilities, native foundations and honest estimates.
- [Wiki Home](https://github.com/franksedivy/watered/wiki/Home): working principles.
- [Persistence](https://github.com/franksedivy/watered/wiki/Persistence) and [Analytics and Privacy](https://github.com/franksedivy/watered/wiki/Analytics-And-Privacy): history, success semantics and collection boundaries.

Apple's linked design-principles page was read on 6 November 2026. This document owns the agreed principles. Reconcile overlapping wiki lists when updating those pages; avoid maintaining competing versions.

The measurement and composition guidance also draws on [Andreas Lüdemann’s Ten Commandments of iOS Development](https://andreaslydemann.com/the-ten-commandments-of-ios-development/), reviewed on 6 November 2026. We adopt these ideas selectively; its tooling examples are not a required stack for Watered.
