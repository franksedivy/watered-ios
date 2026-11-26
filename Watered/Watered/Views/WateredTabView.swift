//
//  WateredTabView.swift
//  Watered
//
//  Created by Frank Sedivy on 30/08/2026.
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - Watered Tab View
/// Coordinates tab navigation, shared sheets and persistence-backed app state.
/// Today receives entries for the active calendar day; Stats receives visible history.
/// Drink and settings actions apply in-memory changes only after persistence succeeds.
struct WateredTabView: View {
    
    // MARK: - Dependencies
    
    /// Receives product events from the app's top-level action handlers.
    ///
    /// The app supplies the implementation, also forwarded through Profile for Health sync actions.
    private let analytics: any AnalyticsClient

    /// The loaded catalogue or a recoverable Add Drink availability failure.
    private let catalogueResult: Result<DrinkCatalogue, Error>

    // MARK: - Tabs
    /// Identifies the top-level tabs for selection and tab-specific overlays.
    private enum WateredTab: String {
        case today = "Today"
        case stats = "Stats"
    }
    
    /// The active tab, used to scope shared overlays.
    @State private var selectedTab: WateredTab = .today
    
    /// Runs after drink insertion and before persistence saves.
    private let beforeDrinkSave: () throws -> Void
    
    /// Runs after display-unit mutation and before persistence saves.
    private let beforeDisplayUnitSave: () throws -> Void

    // MARK: - Settings State
    /// The applied display unit, initially locale-based and then loaded from persistence.
    /// Profile changes apply only after saving succeeds.
    @State private var displayUnit: LiquidUnit = AppSettings.defaults().displayUnit
    
    /// The applied hydration goal, initially the default and then loaded from persistence.
    /// Profile edits remain separate until committed on dismissal.
    @State private var dailyHydrationGoal = AppSettings.defaults().dailyHydrationGoal
    
    /// Holds Profile's uncommitted goal until the sheet closes.
    ///
    /// Opening Profile starts a new draft from the currently applied goal.
    @State private var profileDraftGoal = AppSettings.defaults().dailyHydrationGoal
    
    /// Presents feedback when Profile's final goal could not be saved.
    @State private var isShowingGoalSaveError = false
    
    /// Presents feedback when Profile's selected display unit could not be saved.
    @State private var isShowingDisplayUnitSaveError = false

    /// Owns in-memory drink history shared by the tabs.
    @State private var store = WateredStore()
    
    /// Scopes Today to a calendar day while the store retains visible history.
    @State private var activeCalendarDay = TodayCalendarDay()
    
    /// Connects Profile's selection to explicit persistence.
    ///
    /// Loading saved settings does not invoke this binding's setter.
    private var profileDisplayUnit: Binding<LiquidUnit> {
        Binding(
            get: {
                displayUnit
            },
            set: { selectedUnit in
                commitDisplayUnit(selectedUnit)
            }
        )
    }
    
    // MARK: - Persistence
    /// The app-supplied context used for drink and settings persistence.
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(HealthExportCoordinator.self) private var healthExport: HealthExportCoordinator?
    
    /// Observes non-deleted rows for loading and refreshing the in-memory store.
    @Query(filter: #Predicate<PersistentDrinkEntry> { $0.deletedAt == nil }, sort: \PersistentDrinkEntry.loggedAt) private var persistentDrinkEntries: [PersistentDrinkEntry]

    /// Presents Add Drink above the active tab.
    @State private var isShowingAddDrinkSheet = false

    /// Survives sheet dismissal, but is never written to persistent storage.
    @State private var addDrinkDraft: AddDrinkSheetDraft?
    
    /// Controls the alert shown when saving a submitted drink fails.
    @State private var isShowingDrinkSaveError = false

    /// Recent-menu submissions happen without an Add Drink sheet to host an alert.
    @State private var isShowingRecentDrinkError = false

    /// Presents the shared Profile sheet from either tab.
    @State private var isShowingProfileSheet = false

    // MARK: - Tab Icons
    /// Builds the calendar symbol for the current date using the active calendar.
    private var todayCalendarSymbolName: String {
        let dayOfMonth = activeCalendarDay.calendar.component(.day, from: Date())
        return "\(dayOfMonth).calendar"
    }

    // MARK: - Empty Today Prompt
    /// Shows the first-drink prompt only on Today when its active day has no entries.
    private var shouldShowFirstDrinkPrompt: Bool {
        let isTodaySelected = selectedTab == .today
        let hasNoDrinks = todayEntries.isEmpty

        return isTodaySelected && hasNoDrinks
    }
    
    /// Selects entries by their logged date in the active calendar without changing history.
    private var todayEntries: [DrinkEntry] {
        return store.drinkEntries(
            for: activeCalendarDay.date,
            calendar: activeCalendarDay.calendar
        )
    }
    
    // MARK: - Add Drink Presentation

    /// Shortcuts supported by the current catalogue and preparation options.
    private var recentDrinkOptions: [RecentDrinkOption] {
        guard case .success(let catalogue) = catalogueResult else {
            return []
        }
        return store.recentDrinkOptions(in: catalogue)
    }
    
    // MARK: - Transitions
    /// Connects the Add Drink button and sheet for the zoom transition.
    @Namespace private var addDrinkTransition

    /// The shared identity of the Add Drink transition source and destination.
    private let addDrinkTransitionID = "addDrink"

    // MARK: - Initialisation
    //
    /// Creates the app shell with analytics and optional persistence callbacks.
    ///
    /// Empty callbacks leave normal saving unchanged. Launch configuration and simulated
    /// failure state belong to the app, not this view.
    ///
    /// - Parameters:
    ///   - analytics: The client that receives product events.
    ///   - catalogueResult: The catalogue loaded at startup, or its loading failure.
    ///   - beforeDrinkSave: An action run before saving an inserted drink.
    ///   - beforeDisplayUnitSave: An action run before saving a changed display unit.
    @MainActor
    init(
        analytics: any AnalyticsClient,
        catalogueResult: Result<DrinkCatalogue, Error>,
        beforeDrinkSave: @escaping () throws -> Void = {},
        beforeDisplayUnitSave: @escaping () throws -> Void = {}
    ) {
        self.analytics = analytics
        self.catalogueResult = catalogueResult
        self.beforeDrinkSave = beforeDrinkSave
        self.beforeDisplayUnitSave = beforeDisplayUnitSave
    }
    
    // MARK: - Body
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {

                TodayView(
                    entries: todayEntries,
                    displayUnit: displayUnit,
                    onOpenProfile: openProfile,
                    dailyGoal: dailyHydrationGoal,
                )
                    .tabItem {
                        Label("Today", systemImage: todayCalendarSymbolName)
                    }
                    .tag(WateredTab.today)

                LearnView(
                    onOpenProfile: openProfile,
                    entries: store.entries,
                    displayUnit: displayUnit,
                    onDeleteDrink: deleteDrinkEntry,
                    needsHealthCleanupNotice: { try needsHealthCleanupNotice(for: [$0]) }
                )
                    .tabItem {
                        Label("Stats", systemImage: "chart.bar")
                    }
                    .tag(WateredTab.stats)
            }
            .onChange(of: selectedTab) { previousTab, newTab in
                wateredLog("Selected tab changed from \(previousTab.rawValue) to \(newTab.rawValue)")
            }
            .onAppear {
                loadPersistedDrinkEntries()
                loadPersistedAppSettings()
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                healthExport?.attach(to: modelContext.container)
                healthExport?.setActive(phase == .active)
            }
            .onChange(of: persistentDrinkEntries) {
                loadPersistedDrinkEntries()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.significantTimeChangeNotification
                )
            ) { _ in
                refreshActiveCalendarDay()
            }

            AddDrinkActionButton(
                recentDrinks: recentDrinkOptions,
                displayUnit: displayUnit,
                onSelectRecent: addRecentDrink
            ) {
                wateredLog("Add Drink flow opened")
                isShowingAddDrinkSheet = true
                analytics.track(.addDrinkOpened)
            }

            .frame(width: 88, height: 88)
            .contentShape(Rectangle())
            .matchedTransitionSource(
                id: addDrinkTransitionID,
                in: addDrinkTransition
            )
            .padding(.trailing, 12)
            .padding(.bottom, -26)
            .alert("Could not add recent drink", isPresented: $isShowingRecentDrinkError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your drink wasn't saved. Touch and hold Add drink to try again, or tap it to choose another drink.")
            }


            if shouldShowFirstDrinkPrompt {
                FirstDrinkPrompt()
                    .allowsHitTesting(false)
                    .padding(.trailing, 88)
                    .padding(.bottom, 64)
            }
        }

        .sheet(isPresented: $isShowingAddDrinkSheet, onDismiss: {
            isShowingDrinkSaveError = false
            wateredLog("Add Drink flow dismissed")
        }) {
            Group {
                switch catalogueResult {
                case .success(let catalogue):
                    AddDrinkView(
                        catalogue: catalogue,
                        defaultUnit: displayUnit,
                        recentDrinkOptions: recentDrinkOptions,
                        retainedDraft: $addDrinkDraft,
                        onAddDrink: addDrinkEntry
                    )
                case .failure(let error):
                    ContentUnavailableView(
                        "Drinks unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(
                            "Close and reopen Watered to try again. "
                            + "Saved drinks can still be viewed in Stats."
                        )
                    )
                    .presentationDetents([.medium, .large])
                    .onAppear {
                        wateredLog("Catalogue loading failed: \(error.localizedDescription)")
                    }
                }
            }
            .navigationTransition(
                .zoom(
                    sourceID: addDrinkTransitionID,
                    in: addDrinkTransition
                )
            )
            .presentationDragIndicator(.visible)
            .alert("Could not save your drink", isPresented: $isShowingDrinkSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your drink wasn't saved. Please try again.")
            }
        }
        .sheet(isPresented: $isShowingProfileSheet, onDismiss: commitProfileGoal) {
            Group {
                #if DEBUG
                ProfileView(
                    displayUnit: profileDisplayUnit,
                    dailyHydrationGoal: $profileDraftGoal,
                    analytics: analytics,
                    onDeleteAllDrinks: {
                        try deleteDrinkEntries(persistentDrinkEntries)
                    },
                    needsHealthCleanupNoticeForReset: {
                        try needsHealthCleanupNotice(for: Set(persistentDrinkEntries.map(\.id)))
                    }
                )
                #else
                ProfileView(
                    displayUnit: profileDisplayUnit,
                    dailyHydrationGoal: $profileDraftGoal,
                    analytics: analytics
                )
                #endif
            }
            .alert(
                "Could not save your display unit",
                isPresented: $isShowingDisplayUnitSaveError
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your previous unit is still selected. Please try again.")
            }
        }
        .alert("Could not save your goal", isPresented: $isShowingGoalSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your previous goal is still active. Please reopen Profile and try again.")
        }
    }

    // MARK: - Actions

    /// Replaces in-memory history with mapped, non-deleted rows from the query.
    /// Unmappable rows are skipped and counted in diagnostics, but remain in storage.
    private func loadPersistedDrinkEntries() {
        let loadedEntries = persistentDrinkEntries.compactMap { persistentDrinkEntry in
            persistentDrinkEntry.drinkEntry()
        }
        
        let skippedEntryCount = persistentDrinkEntries.count - loadedEntries.count
        
        if skippedEntryCount > 0 {
            wateredLog("Persistence skipped \(skippedEntryCount) stored drink rows that could not be mapped.")
        }
        
        wateredLog("Persistence read finished with \(loadedEntries.count) drink entries")
        store.loadDrinkEntries(loadedEntries)
    }
    
    /// Loads saved settings, creating first-run settings and initial goal history if needed.
    ///
    /// Existing settings are preserved. If loading fails or stored values cannot be mapped, the current UI state remains
    /// unchanged and the failure is logged.
    private func loadPersistedAppSettings() {
        do {
            let persistentSettings = try AppSettingsPersistence.loadOrCreate(
                defaults: AppSettings.defaults(),
                in: modelContext
            )
            
            guard let appSettings = persistentSettings.appSettings() else {
                wateredLog("Settings could not be mapped; keeping current UI values.")
                return
            }
            
            displayUnit = appSettings.displayUnit
            dailyHydrationGoal = appSettings.dailyHydrationGoal
            
            wateredLog(
                "Settings loaded with dsipaly unit \(displayUnit.rawValue)"
                + " and daily hydration goal \(dailyHydrationGoal.amount.formatted)"
            )
        } catch {
            wateredLog("Settings loading failed: \(error.localizedDescription)")
        }
    }
    
    /// Commits Profile's final goal when its sheet closes.
    ///
    /// Persistence skips unchanged goals. Today receives the draft only after the operation succeeds; a failure leaves the
    /// applied goal unchanged.
    private func commitProfileGoal() {
        do {
            let settings = try AppSettingsPersistence.loadOrCreate(
                defaults: AppSettings.defaults(),
                in: modelContext
            )
            
            let didChange = try AppSettingsPersistence.saveGoal(
                profileDraftGoal,
                source: .manual,
                settings: settings,
                in: modelContext
            )
            
            dailyHydrationGoal = profileDraftGoal
            
            if !didChange {
                wateredLog("Profile closed without a goal change.")
            }
        } catch {
            wateredLog("Profile goal save failed: \(error.localizedDescription)")
            isShowingGoalSaveError = true
        }
    }
    
    private func needsHealthCleanupNotice(for ids: Set<UUID>) throws -> Bool {
        guard healthExport != nil else { return false }
        return try HealthExportPersistence.needsCleanupNotice(for: ids, in: ModelContext(modelContext.container))
    }

    /// Deletes one logical drink entry identified by its stable UUID.
    ///
    /// Finds the matching persisted rows and delegates saving and store updates to the shared deletion function.
    /// An already-absent entry requires no deletion.
    ///
    /// - Throws: A persistence error if saving fails.
    private func deleteDrinkEntry(id: UUID) throws {
        let matchingEntries = persistentDrinkEntries.filter { entry in
            entry.id == id
        }
        
        wateredLog("Drink deletion requested.")
        try deleteDrinkEntries(matchingEntries)
    }

    
    /// Deletes stored drinks before updating the in-memory history.
    ///
    /// - Parameter entriesToDelete: Stored records belonging to this view's context.
    /// - Throws: A persistence error, leaving the in-memory history unchanged.
    private func deleteDrinkEntries(
        _ entriesToDelete: [PersistentDrinkEntry]
    ) throws {
        let deletedIDs = try DrinkEntryPersistence.delete(
            entriesToDelete,
            in: modelContext,
            tracksHealthExports: healthExport != nil
        )
        
        guard deletedIDs.isEmpty == false else {
            return
        }
        
        let remainingEntries = store.entries.filter { entry in
            deletedIDs.contains(entry.id) == false
        }
        
        store.loadDrinkEntries(remainingEntries)
        healthExport?.wake()
    }
    
    /// Repeats a supported shortcut with a fresh identity, time and current catalogue rules.
    /// Uses the same save boundary and recent-submission analytics as the former sheet shortcuts.
    private func addRecentDrink(_ option: RecentDrinkOption) {
        guard case .success(let catalogue) = catalogueResult else {
            isShowingRecentDrinkError = true
            return
        }
        do {
            let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
            let entry = try option.drinkEntry(using: resolver)
            addDrinkEntry(entry, method: .recent)
        } catch {
            wateredLog("Recent drink preparation failed.")
            isShowingRecentDrinkError = true
        }
    }

    /// Submits a drink and closes the sheet only after success.
    ///
    /// - Parameters:
    ///  - entry: The submitted drink
    ///  - method: Whether submission came from the form or a recent-drink shortcut.
    /// - Important: Failures preserve the sheet draft or report directly from the recent menu.
    private func addDrinkEntry(_ entry: DrinkEntry, method: AddDrinkSubmissionMethod) {
        let handler = DrinkSubmissionHandler(store: store, analytics: analytics)
        
        do {
            try handler.submit(
                entry,
                method: method,
                save: persistDrinkEntry
            )
            if addDrinkDraft != nil {
                addDrinkDraft = nil
                wateredLog("Add Drink session draft cleared after successful save")
            }
            isShowingAddDrinkSheet = false
            healthExport?.wake()
        } catch {
            wateredLog("Drink save failed.")
            if isShowingAddDrinkSheet {
                isShowingDrinkSaveError = true
            } else {
                isShowingRecentDrinkError = true
            }
        }
    }
    
    /// Delegates drink insertion and saving to the persistence layer.
    ///
    /// Forwards the callback supplied at app startup without interpreting test configuration
    /// or tracking simulated failures.
    ///
    /// - Parameter entry: The drink to persist.
    /// - Throws: A persistence, capture or callback error, including duplicate identity.
    ///   Preliminary pending-edit save and lookup errors propagate without rollback;
    ///   failures after insertion roll back the new transaction, preserving earlier commits.
    /// - Important: Store updates, analytics, and presentation are handled by the caller.
    private func persistDrinkEntry(_ entry: DrinkEntry) throws {
        try DrinkEntryPersistence.save(
            entry,
            in: modelContext,
            healthClient: healthExport?.client,
            beforeSave: beforeDrinkSave
        )
    }

    /// Starts a goal-editing session and presents the shared Profile sheet.
    private func openProfile() {
        profileDraftGoal = dailyHydrationGoal
        wateredLog("Profile opened with a new goal draft.")
        isShowingProfileSheet = true
    }
    
    /// Saves Profile's selected unit before applying it to the app.
    ///
    /// A failed save leaves the current display unit unchanged and requests an alert inside
    /// Profile. First-run settings creation uses the shared persistence operation. Loading
    /// saved settings bypasses this action and does not trigger another unit save.
    ///
    /// - Parameter unit: The display unit selected in Profile.
    private func commitDisplayUnit(_ unit: LiquidUnit) {
        do {
            let settings = try AppSettingsPersistence.loadOrCreate(
                defaults: AppSettings.defaults(),
                in: modelContext
            )
            
            let didChange = try AppSettingsPersistence.saveDisplayUnit(
                unit,
                settings: settings,
                in: modelContext,
                beforeSave: beforeDisplayUnitSave
            )
            
            displayUnit = unit
            
            if didChange {
                wateredLog("Profile display unit applied: \(unit.rawValue)")
            }
        } catch {
            wateredLog("Display unit save failed: \(error.localizedDescription)")
            isShowingDisplayUnitSaveError = true
        }
    }
    
    /// Refreshes Today’s date after a significant system time change without changing history.
    private func refreshActiveCalendarDay() {
        activeCalendarDay.refresh()
        wateredLog(
            "Active Today calendar day refreshed to \(activeCalendarDay.date.formatted(date: .complete, time: .shortened))"
        )
    }
}

// MARK: - Preview

#Preview {
    WateredTabView(
        analytics: NoOpAnalyticsClient(),
        catalogueResult: Result { try DrinkCatalogueLoader().load() }
    )
}

