# HealthKit export lifecycle

Status: approved policy and technical handoff, 22 November 2026. Runtime implementation was pending at that checkpoint; #109/#110 subsequently implemented durable export and cleanup, with Profile controls in #111.
Owner: [#96](https://github.com/franksedivy/watered-ios/issues/96), parent [#106](https://github.com/franksedivy/watered-ios/issues/106).
Mapping: [decision 001](001-healthkit-export-mapping.md).

Current implementation note, 25 November 2026: this record preserves the approved
policy and original handoff. See [Architecture](../ARCHITECTURE.md) for the runtime
owners and [Testing](../TESTING.md) for evidence and limitations. Implemented policy
and closed implementation tickets do not establish final release readiness; #113
owns that reconciliation and #172 owns the standards/contracts audit.

## User contract

Watered remains the primary store. “Sync with Apple Health” means optional one-way export of independently permitted water, caffeine and alcohol samples. HealthKit failure never undoes a saved drink. Request write permissions only; do not add general import or read access. Keep drink details and Health payloads out of analytics and diagnostic logs.

Eligibility begins when sync is enabled and uses entry creation time, not logged drink time. A backdated drink entered after enablement can sync; both sample dates still use the original loggedAt instant. Decide eligibility when committing the new entry using the current sync setting and per-type write authorization. Do not infer eligibility later merely by comparing timestamps.

Only currently authorized types are queued. Denied or undetermined types are omitted for that entry, not backfilled when permission changes. Unknown and known-zero quantities create no sample; invalid quantities/dates produce a per-type failure rather than fabricated values. Saved estimates and the mapping policy determine quantities, never the current catalogue.

Disabling stops new upload starts and pauses pending uploads. An in-flight request may finish; persist its outcome. Entries created while disabled are not queued. Existing Health samples remain. Re-enabling resumes previously eligible pending work and accepts new entries, without filling the disabled gap. Previously queued work blocked by revoked permission resumes when authorization returns; new types permitted later apply only to new entries.

Historical export is excluded from version one and tracked separately in [#165](https://github.com/franksedivy/watered-ios/issues/165). This controls what Watered sends, not Apple Health retention.

## Storage and execution ownership

Add an optional deletedAt to persisted drinks and a small device-local per-entry/per-type export record. Keep export state separate from DrinkEntry.source and immutable catalogue snapshots. Persist the sync preference and enablement boundary. All changes must preserve existing stores; no automatic database reset.

Each export record owns:

- Entry UUID, sample type, frozen quantity/unit, loggedAt, provenance and export-policy version.
- Deterministic sync identifier with a Watered namespace, entry UUID and sample type; initial HealthKit sync version 1. Retry with the same identity and version. Conversion-policy version and HealthKit sync version are separate concepts.
- Desired operation (upload or delete), status (pending, in-flight, succeeded, authorization-blocked or invalid), attempt count, next retry time and non-sensitive failure category.
- Whether a write may have reached Health, and optional returned sample linkage. Cleanup must not depend on receiving a sample UUID before a crash.

Persist a valid entry and its eligible export intents together before reporting local success. Health authorization denial or unavailable HealthKit must not prevent local logging; those types create no new intent. A local database transaction failure is a local save failure, not an export failure. Serialize setting changes and entry creation so eligibility has a definite boundary.

A focused executor owns HealthKit I/O. Serialize operations per entry/type; persist in-flight intent before issuing a request. Persist acknowledgement before treating work as complete. On relaunch, recover uncertain in-flight uploads using the original identity/version; recover uncertain deletes by repeating the same constrained cleanup. A deleted entry always takes precedence over upload, including late callbacks.

Apple documents sync identity/version replacement; it does not establish an exactly-once application transaction. Verify repeated same-version writes on a controlled device. Never increment the version merely to retry. No catalogue update or relaunch resends acknowledged samples. Future edits/revisions need a separate policy.

Retry temporary failures with capped exponential delay and jitter while execution is available, including on reopening; provide Retry now. Scheduling constants belong in #109. Successful types remain complete when another type fails. Authorization-blocked work waits for permission restoration without timed permission prompts. Invalid payloads stop automatic retries for that type and expose an actionable status. No background completion guarantee.

## Deletion and Debug bulk reset

In one local transaction, mark the drink deleted, cancel uploads that have never started, and retain/create cleanup intent for every sent or possibly-sent type. Hide deleted drinks from history, totals, charts and Recents immediately after persistence succeeds. If the transaction fails, do not claim deletion or change the visible model to success.

A never-started upload needs no Health cleanup. A possible in-flight write must settle and then be cleaned up; serialize this race so a late successful write cannot escape deletion. Recovery after a crash conservatively cleans possibly-written types.

Delete only Watered-owned samples matching the entry/type sync identity. Do not delete all Watered samples or other apps' data. A successful delete request matching zero objects resolves cleanup; an authorization failure does not prove absence. Track partial cleanup independently per type.

Disabling sync does not cancel requested deletion cleanup. If permission is revoked or cleanup fails, keep the drink hidden, retain its details and durable cleanup intent, and retry when possible. There is no automatic expiry or repeated permission prompt. Explain: “Deleted from Watered. To remove its Apple Health data, restore permission or delete it in Health.” Manual deletion in Health alone cannot be assumed to resolve a permission-blocked local job without successful cleanup confirmation.

Permanently remove drink details and associated completed records only after every required cleanup is resolved and no in-flight callback can write again. A drink with no possible Health write can be purged immediately; this policy does not add an undo window.

Debug bulk reset applies the same rules to its entire selected set in an atomic local transaction. Preserve existing pending cleanup and sync settings; do not wipe the database file or queue. Confirmation must explain local removal and potentially delayed Health cleanup. Use disposable data for verification.

## Deletion directly in Apple Health

Keep the Watered drink and its acknowledged sent state. Do not query for existence or recreate a sample deleted in Health. Other sample types remain independent. Use “Sent to Apple Health”, which records an action rather than promising the sample still exists. Re-enabling does not resend acknowledged entries; future historical export must also respect these records.

Accepted version-one limitation: if Health saves successfully, Watered stops before recording acknowledgement, and the user deletes the sample in Health, recovery may recreate it. Avoiding this would require additional reconciliation beyond this scope.

## Device boundary and alternatives

The exporter, queue, retries and sample linkage are device-local. Stable drink identity may support a future sync design, but must not be mistaken for multi-device coordination. Do not synchronize local leases, acknowledgements or Health sample UUIDs by default. CloudKit, cross-device conflict handling and a generic job framework are out of scope.

Rejected alternatives: automatic history backfill, queuing unpermitted types for future consent, hard deletion before cleanup, indefinite retention after successful cleanup, treating all types as one exported flag, and polling Health to recreate missing samples. These either contradict consent, lose cleanup intent, retain unnecessary details or duplicate/recreate data unexpectedly.

## Implementation slices and completion evidence

- #107: per-type write authorization and availability; authorization request completion is not proof of individual grants.
- #108: frozen sample mapping and policy context from decision 001.
- #109: additive persistence, atomic intent capture, executor, per-type retries, deduplication and crash recovery.
- #110: deletion filtering, in-flight precedence, cleanup and safe purge; Debug bulk reset.
- #111: enable/disable, per-type status, Retry now, blocked-cleanup and privacy wording.
- #112: fake-client integration plus controlled physical-device verification; coordinate store/schema work with #100/#97.

Required scenarios before implementation is accepted:

| Scenario | Expected evidence |
| --- | --- |
| Enable, backdated entry, disabled gap, re-enable | Entry creation controls eligibility; loggedAt controls sample time; only old eligible pending work resumes |
| Partial denial and later grant/revocation | Types independent; no new denied-type jobs or backfill; existing blocked work can resume |
| Save failure or unavailable Health | No false local success on database failure; Health unavailability does not block local logging |
| One type succeeds, another fails; repeated Retry now | Successful type untouched; original payload/identity/version reused; requests serialized |
| Stop before I/O, after remote save, before acknowledgement | Durable recovery without fabricated completion; same-version behaviour checked on device |
| Invalid data, zero, unknown, recipe change, timezone change | Correct independent omission/failure; no recomputation or timestamp substitution |
| Delete before upload, during upload, after success, during retry | No later orphan write; hidden state persists; cleanup targets only that entry/type |
| Partial delete, absent sample, revoked permission, relaunch | Successful zero-match cleanup resolves; blocked work retained indefinitely; no false purge |
| Bulk reset and failed local transaction | Existing cleanup preserved; rollback honest; settings unchanged; no file wipe |
| All cleanup resolved | Drink details purged only when callbacks cannot recreate data |
| User deletes in Health | Acknowledged sample not recreated; accepted unacknowledged-write limitation demonstrated |
| Existing development store | Additive rollout preserves drinks/snapshots and never silently resets storage |

This handoff closes the policy issue only. No HealthKit runtime, migration or device verification is delivered by this documentation change.

## Apple references

- [Sync identifier](https://developer.apple.com/documentation/healthkit/hkmetadatakeysyncidentifier) and [sync version](https://developer.apple.com/documentation/healthkit/hkmetadatakeysyncversion).
- [Constrained deletion](<https://developer.apple.com/documentation/healthkit/hkhealthstore/deleteobjects(of:predicate:withcompletion:)>).
- [Per-type authorization](<https://developer.apple.com/documentation/healthkit/hkhealthstore/authorizationstatus(for:)>).
