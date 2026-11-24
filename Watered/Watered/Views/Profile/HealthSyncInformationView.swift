import SwiftUI

/// Optional explanations keep the primary screen focused on the person's sync choice.
/// Permission and cleanup recovery remain reachable here even when uploads are off.
struct HealthSyncInformationView: View {
    let authorization: HealthAuthorizationController
    let coordinator: HealthExportCoordinator
    var analytics: any AnalyticsClient = NoOpAnalyticsClient()

    var body: some View {
        Form {
            Section("About syncing") {
                Text("Optional, one-way sharing. Watered works without it and never reads your Health data.")
                Text("Enable sync and allow each type to share new eligible drink estimates. Allowing permission alone does not turn sync on.")
                NavigationLink("Manage permissions") {
                    HealthPermissionsView(authorization: authorization, analytics: analytics)
                }
                .accessibilityIdentifier("healthManagePermissions")
            }

            HealthCleanupSection(coordinator: coordinator)

            Section("What is shared") {
                Text("Water is estimated water content, not drink volume or hydration credit. Caffeine is the saved estimate. Alcohol is an estimated number of 14 g standard drinks, based on volume and strength. Unknown or zero amounts are not sent.")
                Text("Only drinks added while sync and the relevant permission are enabled are eligible, including newly added backdated drinks. Existing history and gaps are not filled in later.")
            }

            Section("Export status and retries") {
                Text("Sent to Apple Health means Health acknowledged the write. It does not mean the sample is still there. Watered does not check for or replace acknowledged samples you delete in Health.")
                Text("Retry sends eligible pending work when sync and permission allow it. Cleanup retries even with sync off. Keep Watered open to let work finish.")
                Text("If permission is needed, use Review permissions. Estimates that could not be sent cannot be repaired by retrying; your drink remains saved in Watered.")
            }

            Section("Turning sync off and deleting drinks") {
                Text("Turning sync off pauses pending uploads and leaves existing Health data in place. An upload already in progress may finish. Turning it back on resumes eligible pending work, without exporting missed history or older entries for newly allowed types.")
                Text("Deleting a drink hides it from Watered after saving the deletion and requests removal of its Watered-created Health samples. Cleanup continues with sync off. If cleanup is delayed, drink details stay on this device until it finishes. Restore permission to complete blocked cleanup; deleting samples manually in Health does not confirm cleanup to Watered.")
            }

            Section("Privacy") {
                Text("Your drink history and export progress are stored on this device. Watered does not send them to our servers or use them for advertising. Health data is handled by Apple according to your Health and iCloud settings.")
                Text("Watered requests write access only for water, caffeine and alcoholic beverages. You can change each permission in Health at any time. Local drink logging remains available.")
            }
        }
        .navigationTitle("Privacy & information")
        .navigationBarTitleDisplayMode(.inline)
    }
}
