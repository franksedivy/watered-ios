# Watered agent guidance

Agreed project guidance. Read alongside [Contributing](CONTRIBUTING.md).

## Collaboration

Implement work when Frank asks for implementation. When he says “you guide, I do”, give one small explained action, wait for his result and review it before continuing. Do not scaffold or edit in that mode unless invited. Preserve an explicitly chosen working mode across follow-ups.

Keep explanations plain and proportional to the task. Small comment or copy edits should stay small. Ask only when missing information materially affects scope, correctness or an authorization boundary; continue independent authorized work meanwhile.

## Start and scope

- Read the task and relevant docs, then inspect branch, working tree and affected code. Preserve unrelated changes.
- Define the outcome and observable completion checks. Keep one independently reviewable change per task; a release chat coordinates scope rather than accumulating implementation.
- Reuse the suitable checkout. Use a focused branch; isolate concurrent writers if parallel work is explicitly requested. Do not create extra chats or delegate unless requested.
- Treat unrelated improvements as follow-ups. Do not broaden a bug fix into general cleanup.

Investigation default: after roughly 15 minutes, report what evidence has been found and the next hypothesis. After two attempts produce no new evidence, change approach or explain the precise blocker. A useful checkpoint is not a claim that the task is finished.

## Implementation

Use the [project principles](Docs/PRINCIPLES.md) for the reasoning behind these conventions. Follow the model-first approach and existing Swift conventions. Keep calculation, persistence, presentation and view responsibilities distinct; prefer a focused extraction over a speculative framework. Update concise `///` comments when the changed contract needs explanation.

Preserve these current contracts:

- Logged drinks retain captured catalogue facts; new catalogue content must not rewrite history.
- Unknown estimates remain unknown, distinct from zero or negative values.
- Persistence succeeds before in-memory drink state and success analytics change.
- Repeating a recent drink creates a new entry under current catalogue rules.
- Profile goal edits commit once on dismissal when changed; display-unit changes do not create goal history.
- Never silently reset a user's database. Development-data deletion requires an explicit user action.
- Debug analytics are local; Release analytics discard events. HealthKit remains planned in this baseline.

See [Architecture](Docs/ARCHITECTURE.md) for source pointers, and verify affected contracts against current code.

## Verification and completion

Use [Testing](Docs/TESTING.md) to select checks. Agent-run simulator suites default to hosted CI; do not bypass the CI runner's local-execution guard. Documentation-only edits need link and whitespace checks, not an iOS suite. Add regression tests for meaningful behaviour changes, particularly persistence and calculations.

Report exactly what ran, on which revision/environment, and what remains unverified. Focused green tests are not a full-suite pass; simulator checks are not physical-device review. Do not repeat passed checks without a new change or unresolved concern.

Before a commit, inspect the full diff and explicitly include intended new files. Keep commits focused. Reference the relevant tickets in every commit message, including any related or parent tickets that the change contributes to, for example `Add reviewed tea estimates (#101, #102)`. A PR should explain the problem, resulting behaviour and verification. Explicit agreement is required before merging or publishing a release; issue or PR approval does not itself authorize production release.

Finish with the changed behaviour, checks and result, limitations and any required next action. For unfinished work moving chats, use the [handoff template](Docs/handoffs/TEMPLATE.md). Do not mark incomplete work done because a time budget ended.
