# Apple Health privacy and controls

Implementation review for [#111](https://github.com/franksedivy/watered-ios/issues/111),
parent [#106](https://github.com/franksedivy/watered-ios/issues/106), 24 November 2026.
This is repository-owned wording and a source review, not evidence of published
App Store answers, an approved distribution archive or a published privacy policy.

## Privacy-policy wording for optional Apple Health export

Watered stores your drink history, settings and export progress on your device.
Watered does not send your drink history or Health data to our servers or use it
for advertising. You can use local drink logging without Apple Health.

“Sync with Apple Health” is optional one-way export. Watered requests permission
to write water, caffeine and alcoholic beverages separately; it does not read
Health data. Water is saved estimated water content, not beverage volume or hydration
credit. Caffeine uses saved estimates. Alcohol uses saved volume and strength to
estimate fractional 14 g standard drinks. Unknown or zero amounts are not sent.
Samples use the time the drink was logged for, including backdated new entries.
Apple handles Health data according to your Health and iCloud settings; Watered's
local exporter does not imply that Health data remains only on this device.

Only new entries created while sync and the relevant permission are enabled become
eligible. Existing history, entries added while disabled and older entries for newly
allowed types are not exported later. Turning sync off pauses pending uploads and
leaves existing Health data in place; an upload already in progress may finish.
Turning it back on resumes previously eligible pending work. Change permissions in
Health → profile → Apps → Watered. No retry automatically requests permission.

Deleting a drink hides it from Watered after the deletion is saved and requests
cleanup of its Watered-created Health samples. Cleanup continues with sync off.
The hidden drink's details and pending cleanup remain on device until cleanup is
confirmed, with no automatic expiry. Restore permission for blocked cleanup.
You can remove samples in Health, but that alone does not confirm cleanup to Watered.
Only matching Watered samples are targeted, never other apps' data.

“Sent to Apple Health” records acknowledgement of a write, not current presence in
Health. Acknowledged samples removed in Health are not recreated. If Health saves
but Watered stops before acknowledgement, recovery can recreate a sample removed
in the meantime. Retries do not promise exactly-once or background completion.

## Source review and App Store answers

Inspected `WateredApp`, the analytics clients/events, HealthKit client, mapping,
preference/export persistence and coordinator, project dependencies and source API
usage. Release discards analytics. Debug logs approved interaction events locally.
The two Health permission actions have no properties; opt-in, retries, grants,
denials, errors, quantities and identifiers introduce no analytics events/properties.
The Debug inspection screen displays synthetic/test records locally, not telemetry.

Under Apple's [collection definition](https://developer.apple.com/app-store/app-privacy-details/),
on-device processing alone is not collection. The inspected app has no third-party
SDK dependencies, analytics upload or developer-accessible Health/drink transmission.
**The source-supported answer is Data Not Collected for this implementation**, subject
to verification against the final distributed app and any external services. This is
not a claim of Data Not Linked to You, anonymisation, or an already-saved App Store
Connect answer. Any future collection requires a fresh review of data types,
identity linkage, purposes, tracking, providers and disclosures.

Both build configurations already contain Health write/read usage descriptions;
the read description accurately says Watered does not read Health data, and the
request read set is empty. #111 does not change entitlements or permission scope.

No `PrivacyInfo.xcprivacy` exists in the baseline. This change adds no required-reason
API, tracking domain, collection SDK or network transport. A source search found no
app use of UserDefaults/AppStorage, file timestamps, boot-time, disk-space or active
keyboard APIs; the catalogue loader checks bundled file existence only. HealthKit
permission descriptions are separate from privacy-manifest declarations. Do not add
invented reason codes or declare Health data as collected merely because it is
written to the local Health store. Apple's [required-reason guidance](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
requires declarations for covered APIs actually used. Final archive privacy-report
and App Store validation remain release checks; this source review is not binary
validation or approval of every future dependency.

## Publication and verification boundary

The in-app screen contains the relevant sharing, retention and recovery explanation.
No published policy URL or App Store Connect answers were available in this checkout;
apply the reviewed wording to the published policy before release and compare the
final archive's privacy report with the submitted answers. The wiki's
[Analytics and Privacy](https://github.com/franksedivy/watered-ios/wiki/Analytics-And-Privacy)
page is historical context; its event inventory predates the permission events.
Repository source and this review own current behavior.

Final-screen VoiceOver, large text, contrast, real prompts and Release signing/device
checks still need observed evidence. See [Testing](TESTING.md#healthkit-profile-controls-111).
Broader lifecycle/device verification remains [#112](https://github.com/franksedivy/watered-ios/issues/112).
