# Contributing to Watered

Project workflow agreed on 6 November 2026. See [project principles](Docs/PRINCIPLES.md) for the reasoning behind it.

## Setup

Open `Watered/Watered.xcodeproj` in Xcode and select the shared `Watered` scheme. The README specifies Xcode 27 or later; the app target currently requires iOS 27. CI's exact toolchain pins belong in [Continuous Integration](Docs/Continuous-Integration.md).

Use synthetic data for testing. Before working with older development stores, read [Development Drink Data](Docs/Development-Drink-Data.md); do not delete data as an automatic setup step.

## Change workflow

The README establishes focused branches from `main`, one issue or coherent change per PR, relevant verification, screenshots or recordings for UI changes, and documentation updates alongside behaviour changes.

1. Check the current branch and uncommitted work. Confirm the issue's intended result and scope.
2. Start a focused branch from the appropriate base. Existing history uses `feature/`, `bugfix/` and `refactor/`; agent-created branches can use `codex/<issue>-<description>`. Existing branches do not need renaming.
3. Implement a small coherent slice following existing model and persistence boundaries.
4. Run relevant checks from [Testing](Docs/TESTING.md), inspect `git diff --check` and review the diff, including new files.
5. Only when Frank explicitly requests it, open a PR referencing the relevant and parent issues. Describe the concrete problem, resulting behaviour, verification and limitations. Include visual evidence for UI changes and complete the metadata checklist below.
6. Obtain explicit merge agreement. A successful check or approved issue does not authorize a release.

Do not silently skip CI or broaden a change to make unrelated tests pass. If a prototype intentionally has unverified behaviour, document the gap and agree its verification before treating it as release-ready.

## PR metadata checklist

Complete these checks when creating any PR, including drafts, and recheck them when scope changes. Inspect the relevant and parent tickets and existing repository conventions; do not guess assignments or create new labels, milestones or projects merely to fill fields.

- **Assignee:** assign the person responsible for delivery; for Frank's Watered work, use `franksedivy` unless another owner is agreed.
- **Labels:** apply existing labels that describe the actual change, such as `enhancement`, `bug` or `documentation`. Do not copy unrelated issue labels automatically.
- **Milestone:** use the agreed release milestone from the owning issue when the PR contributes to that release.
- **Projects:** add the PR to the relevant existing project and set applicable status/fields when one is in use. Check the owning and parent issues. If no project applies, leave it unset and say so; if access prevents checking or updating it, report the limitation.
- **Reviewers:** request the agreed eligible reviewer or team. GitHub does not allow the PR author to review their own PR; do not invent a reviewer simply to populate the field. Explain when no eligible reviewer is designated.
- **Development / issue links:** reference all relevant and parent tickets in the description. Use closing keywords or GitHub's closing links only when the PR fully resolves that issue. For partial category deliveries, use `Refs #…`; an empty Development field is acceptable when automatic closure would be incorrect.

Read back the saved metadata before reporting completion. Briefly identify any intentionally unset fields or permission limitations. Metadata completion does not authorize a merge or release.

## Repetitive checks and formatting

Agree a small, consistent set of formatting rules and automate their checking rather than repeatedly debating style in reviews. Formatter selection, configuration and CI integration remain follow-up implementation work; this document does not establish that tooling is installed.

Introduce formatting in a dedicated change, separate from behaviour changes. Keep any initial formatting diff reviewable and avoid unrelated formatting churn during a fix. Use the same configuration locally and in CI once adopted.

## Chat workflow

Use one coordination chat per release for committed scope, deferred work, dependencies and decisions. Use a focused implementation chat for each independently reviewable outcome. Use a release-verification chat for integration checks and the release decision.

Each implementation brief needs: outcome, included/excluded scope, completion evidence and working mode (autonomous implementation or guided checkpoints). Default to one active coding task. New discoveries become follow-up issues unless necessary for the current outcome. Close completed chats after recording results in the issue or PR.

For interrupted work, write a short [handoff](Docs/handoffs/TEMPLATE.md) only when the issue or PR lacks enough context to resume.

## Information ownership

| Information | Home |
| --- | --- |
| Product introduction and setup entry point | [README](README.md) |
| Backlog, acceptance criteria and release scope | GitHub issues and milestones |
| Changed behaviour and verification evidence | Pull request |
| Agent collaboration rules | [Agent guidance](AGENTS.md) |
| Implementation map | [Architecture](Docs/ARCHITECTURE.md) |
| Check selection and manual scenarios | [Testing](Docs/TESTING.md) |
| Hosted runner details | [Continuous Integration](Docs/Continuous-Integration.md) |
| Release procedure | [Releasing](Docs/RELEASING.md) |
| Significant technical rationale | Existing wiki Decision Log; new [decision records](Docs/decisions/TEMPLATE.md) |

Repository docs own current implementation and workflow guidance. The wiki retains research, narrative and historical decisions. When a topic is updated, reconcile its wiki counterpart and link to the repository guidance rather than maintaining competing instructions. Historical wiki content has not been exhaustively migrated. Do not maintain parallel TODO, status or roadmap files that disagree with GitHub.
