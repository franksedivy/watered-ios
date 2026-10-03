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
//
// Purpose: Define Watered's top-level tab navigation.
//
// Returns:
// A native SwiftUI TabView containing the main app areas.
//
// UI role:
// Acts as Watered's main app shell. It owns tab selection, app-wide sheet
// presentation, the floating Add Drink action, and the shared Profile entry
// point so those controls behave consistently across top-level screens.
//
// It also bridges app-level state into the visible tabs: Today receives only
// entries for the active local calendar day, while Stats receives the full
// drink history for debugging and persistence validation.
//
// Notes:
// WateredTabView currently sits at the boundary between SwiftUI navigation,
// SwiftData persistence, and WateredStore. It hydrates the store from persisted
// entries, saves new Add Drink submissions, and refreshes Today when iOS reports
// a significant time change.
struct WateredTabView: View {
    
    // MARK: - Dependencies
    
    /// Receives product events from the app's top-level action handlers.
    ///
    /// The app supplies the implementation. Child views remain indepenedent of analytics aclients and provider SDKs
    private let analytics: any AnalyticsClient

    // MARK: - Tabs
    //
    // Purpose: Defines the top-level app tabs that Watered currently supports.
    //
    // UI role:
    // Gives the TabView a typed selection value so app-level overlays, such as the
    // empty-state add-drink prompt, can react to the currently selected tab.
    private enum WateredTab: String {
        case today = "Today"
        case stats = "Stats"
    }
    
    // Purpose: Stores the currently selected top-level app tab.
    //
    // UI role: Lets WateredTabView show app-level UI only when it belongs to the
    // active tab.
    @State private var selectedTab: WateredTab = .today

    // MARK: - Settings State
    //
    // Purpose: Stores the display unit selected for the app.
    //
    // UI role:
    // Stores the display unit currently applied across Watered's top-level views.
    // TodayView uses it to format volume summaries, AddDrinkView uses it as the
    // default logging unit, and ProfileView can change it through a binding.
    //
    // Persistence role:
    // Starts from Watered's locale-aware defaults, then gets replaced by persisted
    // settings when a saved setting exists.
    @State private var displayUnit: LiquidUnit = AppSettings.defaults().displayUnit
    
    // Purpose:
    // Stores the daily hydration goal currently applied to Today.
    //
    // UI role:
    // TodayView uses this goal to calculate and display hydration progress,
    // remaining hydration, and goal-reached states.
    //
    // Persistence role:
    // Starts from Watered's first-run defaults, then gets replaced by persisted
    // settings when a saved goal exists.
    @State private var dailyHydrationGoal = AppSettings.defaults().dailyHydrationGoal
    
    /// Holds Profile's uncomitted goal until the sheet closes.
    ///
    /// Opening Profile starts a new draft from the currently applied goal.
    @State private var profileDraftGoal = AppSettings.defaults().dailyHydrationGoal
    
    /// Presents feedback when Profile's final goal could not be saved.
    @State private var isShowingGoalSaveError = false

    // Purpose: Stores Watered's first app-level state owner.
    //
    // UI role:
    // Keeps drink entries above the tab views without making WateredTabView
    // directly own or mutate the entries array.
    @State private var store = WateredStore()
    
    // Purpose:
    // Stores the local calendar day currently shown by Today.
    //
    // Notes:
    // Lets Today render a day-specific view while WateredStore keeps the full
    // persisted drink history.
    @State private var activeCalendarDay = TodayCalendarDay()
    
    // MARK: - Persistence
    //
    // Purpose:
    // Gives WateredTabView access to the SwiftData context supplied by WateredApp.
    //
    // UI role:
    // Lets the Add Drink submission boundary save new drink entries.
    @Environment(\.modelContext) private var modelContext
    
    // Purpose:
    // Reads persisted drink entries from SwiftData.
    //
    // UI role:
    // Lets WateredTabView hydrate WateredStore when the app starts.
    @Query(sort: \PersistentDrinkEntry.loggedAt) private var persistentDrinkEntries: [PersistentDrinkEntry]
    
    // Purpose:
    // Reads persisted app settings from SwiftData.
    //
    // UI role:
    // Lets WateredTabView hydrate app-level settings, such as display unit and
    // daily hydration goal, when the app starts.
    @Query private var persistentAppSettings: [PersistentAppSettings]

    // Purpose: Controls whether the Add Drink sheet is visible.
    //
    // UI role:
    // Keeps AddDrinkView out of the tab bar while still allowing it to appear as a
    // focused add-drink flow above the current tab.
    @State private var isShowingAddDrinkSheet = false
    
    /// Controls the alert shown when saving a submitted drink fails.
    @State private var isShowingDrinkSaveError = false

    // Purpose: Controls whether the Profile sheet is visible.
    //
    // UI role:
    // Keeps profile presentation at the app-tab level so the same profile button
    // can appear on multiple top-level screens.
    @State private var isShowingProfileSheet = false

    // MARK: - Tab Icons
    // Builds the SF Symbol name for today's calendar day.
    //
    // Returns:
    // A Symbol name such as "1.calendar", "24.calendar", or "31.calendar".
    private var todayCalendarSymbolName: String {
        let dayOfMonth = activeCalendarDay.calendar.component(.day, from: Date())
        return "\(dayOfMonth).calendar"
    }

    // MARK: - Empty Today Prompt
    //
    // Purpose: Decide whether the first-drink prompt should be visible
    // Returns: true when the user is on Today and has not logged any drinks
    //
    // UI role:
    // Keeps the prompt attached to the app-level add-drink action without showing
    // it over unrelated tabs such as Learn.
    private var shouldShowFirstDrinkPrompt: Bool {
        let isTodaySelected = selectedTab == .today
        let hasNoDrinks = todayEntries.isEmpty

        return isTodaySelected && hasNoDrinks
    }
    
    // Purpose:
    // Returns the drink entries that belong to the active Today calendar day.
    //
    // Returns:
    // DrinkEntry values from WateredStore whose loggedAt date falls on the same
    // local calendar day as activeCalendarDay.
    //
    // UI role:
    // Keeps Today scoped to one day without deleting previous-day entries from
    // persistence or app state.
    private var todayEntries: [DrinkEntry] {
        return store.drinkEntries(
            for: activeCalendarDay.date,
            calendar: activeCalendarDay.calendar
        )
    }
    
    // MARK: - Add Drink Presentation
    
    /// The available sheet heights for the current Add Drink content.
    ///
    /// Without recent drinks, the sheet uses the smaller system height.
    /// With recents, it retains the existing taller layout. Both configurations
    /// allow expansion to full height.
    private var addDrinkPresentationDetents: Set<PresentationDetent> {
        if store.recentDrinkOptions.isEmpty {
            return [.fraction(0.50), .large]
        }
        
        return [.fraction(0.64), .large]
    }

    // MARK: - Transitions
    //
    // Purpose:
    // Provides the shared animation namespace used to visually connect the
    // floating Add Drink button with the Add Drink sheet.
    //
    // UI role:
    // Lets SwiftUI treat the button as the source of the sheet's zoom transition.
    @Namespace private var addDrinkTransition

    // Purpose:
    // Gives the Add Drink button and Add Drink sheet a shared transition identity.
    private let addDrinkTransitionID = "addDrink"

    // MARK: - Initialisation
    //
    /// Crates the app shell without analytics reporting.
    ///
    /// Constructs the default client on the main actor.
    init() {
        self.init(analytics: NoOpAnalyticsClient())
    }
    
    /// Creates the app shell with an explicitly supplied analytics client.
    ///
    /// - Parameter analytics: The client that recieves product events.
    @MainActor
    init(analytics: any AnalyticsClient) {
        self.analytics = analytics
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
                    onDeleteDrink: deleteDrinkEntry
                )
                    .tabItem {
                        Label("Stats", systemImage: "chart.bar")
                    }
                    .tag(WateredTab.stats)
            }
            .onChange(of: displayUnit) { previousUnit, newUnit in
                wateredLog("Display unit changed from \(previousUnit.rawValue) to \(newUnit.rawValue)")
                saveDisplayUnit(newUnit)
            }
            .onChange(of: selectedTab) { previousTab, newTab in
                wateredLog("Selected tab changed from \(previousTab.rawValue) to \(newTab.rawValue)")
            }
            .onAppear {
                loadPersistedDrinkEntries()
                loadPersistedAppSettings()
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

            AddDrinkActionButton {
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
            AddDrinkView(
                defaultUnit: displayUnit,
                recentDrinkOptions: store.recentDrinkOptions,
                onAddDrink: addDrinkEntry
            )
            .navigationTransition(
                .zoom(
                    sourceID: addDrinkTransitionID,
                    in: addDrinkTransition
                )
            )
            .presentationDetents(addDrinkPresentationDetents)
            .presentationDragIndicator(.visible)
            .alert("Could not save your drink", isPresented: $isShowingDrinkSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your drink wasn't saved. Please try again.")
            }
        }
        .sheet(isPresented: $isShowingProfileSheet, onDismiss: commitProfileGoal) {
            #if DEBUG
            ProfileView(
                displayUnit: $displayUnit,
                dailyHydrationGoal: $profileDraftGoal,
                onDeleteAllDrinks: {
                    try deleteDrinkEntries(persistentDrinkEntries)
                }
            )
            #else
            ProfileView(
                displayUnit: $displayUnit,
                dailyHydrationGoal: $profileDraftGoal
            )
            #endif
        }
        .alert("Could not save your goal", isPresented: $isShowingGoalSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your previous goal is still active. Please reopen Profile and try again.")
        }
    }

    // MARK: - Actions

    // Purpose:
    // Loads persisted drink entries into Watered's app-level store.
    //
    // Behavior:
    // Converts SwiftData rows back into DrinkEntry values and ignores rows that no
    // longer map to known model values.
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
    
    // Purpose:
    // Saves the selected display unit to Watered's persisted app settings.
    //
    // Input:
    // Accepts the display unit selected from Profile.
    //
    // Behavior:
    // Updates the existing settings row when one exists, or creates a new settings
    // row using Watered's current first-run defaults when settings have not yet
    // been persisted.
    private func saveDisplayUnit(_ displayUnit: LiquidUnit) {
        let settings = persistentAppSettings.first ?? PersistentAppSettings(
            appSettings: AppSettings(
                displayUnit: displayUnit,
                dailyHydrationGoal: dailyHydrationGoal
            )
        )
        
        settings.displayUnitID = displayUnit.persistenceIdentifier
        settings.updatedAt = Date()
        
        if persistentAppSettings.isEmpty {
            modelContext.insert(settings)
            wateredLog("Settings created with display unit \(displayUnit.rawValue)")
        } else {
            wateredLog("Settings updated with display unit \(displayUnit.rawValue)")
        }
    }
    
    /// Commits Profile's final goal when its sheet closes.
    ///
    /// Persistence skips unchanged goals. Today recieves the draft only after the operation succeeds, a failuure leaves the
    /// applied goal unchanged
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
    
    // Purpose:
    // Deletes one logical dirnk entry identified by its stable UUID.
    //
    // Input:
    // Accepts the ID of the drink selected in the Stats detail screen.
    //
    // Behavior:
    // Finds the matching persisted rows and delegates saving and store updates
    // to the shared deletion function. An already-absent entry requires no deletion.
    //
    // Throw:
    // A persistence error if saving fails.
    private func deleteDrinkEntry(id: UUID) throws {
        let matchingEntries = persistentDrinkEntries.filter { entry in
            entry.id == id
        }
        
        wateredLog("Deletion requested for drink entry \(id)")
        try deleteDrinkEntries(matchingEntries)
    }

    
    // Purpose:
    // Deletes selected saved drinks and updates the app's in-memory history
    //
    // Input:
    // Accepts persistent drink entries belonging to this view's model context.
    //
    // Behavior:
    // Saves existing changes first so rollback cannot discard pednding settings.
    // Updates WateredStore only after the deletion saves successfully.
    //
    // Throws:
    // A persistence error if either saves fails. Failed deletions are rolled back
    // so the caller can display an error without rpeorting a successful deletion.
    private func deleteDrinkEntries(
        _ entriesToDelete: [PersistentDrinkEntry]
    ) throws {
        guard entriesToDelete.isEmpty == false else {
            return
        }
        
        if modelContext.hasChanges {
            try modelContext.save()
        }
        
        // Capture IDs befor saving the deletion invalidates the stored objects.
        let deletedIDs = Set(entriesToDelete.map { entry in
            entry.id
        })
        
        for entry in entriesToDelete {
            modelContext.delete(entry)
        }
        
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            wateredLog("Drink deletion failed: \(error.localizedDescription)")
            throw error
        }
        
        let remainingEntries = store.entries.filter { entry in
            deletedIDs.contains(entry.id) == false
        }
        
        store.loadDrinkEntries(remainingEntries)
        wateredLog("Deleted \(entriesToDelete.count) saved drink entries")
    }
    
    /// Submits a drink and closes the sheet only after success.
    ///
    /// - Parameters:
    ///  - entry: The submitted drink
    ///  - method: Whether subission came from the form or a recent-drink shortcut.
    /// - Important: On failure, the sheet satys open and presents a save-error alert.
    private func addDrinkEntry(_ entry: DrinkEntry, method: AddDrinkSubmissionMethod) {
        let handler = DrinkSubmissionHandler(store: store, analytics: analytics)
        
        do {
            try handler.submit(
                entry,
                method: method,
                save: persistDrinkEntry
            )
            isShowingAddDrinkSheet = false
        } catch {
            wateredLog("Drink save failed: \(error.localizedDescription)")
            isShowingDrinkSaveError = true
        }
    }
    
    /// INserts a drink into SwiftData and explicitly saves the context.
    ///
    /// - Parameter entry: The drink to persist.
    /// - Throws: The save error after pending context changes have been rolled back.
    /// - Important: This funciton does not update app state or record analytics.
    private func persistDrinkEntry(_ entry: DrinkEntry) throws {
        let persistentDrinkEntry = PersistentDrinkEntry(drinkEntry: entry)
        
        wateredLog("Persistence insert started for drink entry \(entry.id)")
        modelContext.insert(persistentDrinkEntry)
        
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    
        wateredLog("Persistence save succeeded for drink entry \(entry.id)")
    }

    /// Starts a goal-editing session and presents the shared Profile sheet.
    private func openProfile() {
        profileDraftGoal = dailyHydrationGoal
        wateredLog("Profile opened with a new goal draft.")
        isShowingProfileSheet = true
    }
    
    // Purpose:
    // Refreshes the local calendar day shown by Today.
    //
    // Behavior:
    // Updates activeCalendarDay after iOS reports a significant time change, such
    // as midnight, daylight saving changes, or manual clock updates.
    private func refreshActiveCalendarDay() {
        activeCalendarDay.refresh()
        wateredLog(
            "Active Today calendar day refreshed to \(activeCalendarDay.date.formatted(date: .complete, time: .shortened))"
        )
    }
}

#Preview {
    WateredTabView()
}
