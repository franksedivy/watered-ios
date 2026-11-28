import Foundation

/// Derives from applied settings and visible, committed entries supplied by the app.
/// The caller excludes drafts and deleted rows after successful persistence; this pure
/// boundary neither reads storage nor accepts a catalogue that could reinterpret history.
nonisolated enum WidgetSummaryDerivation {
    static func derive(committedEntries: [DrinkEntry], appliedSettings: AppSettings,
                       at now: Date, calendar: Calendar) -> WidgetSummaryReadResult {
        guard now.timeIntervalSince1970.isFinite,
              let day = calendar.dateInterval(of: .day, for: now) else { return .unavailable }
        // Matches WateredStore's calendar-day selection, including non-24-hour days.
        let entries = committedEntries.filter { calendar.isDate($0.loggedAt, inSameDayAs: now) }
        let snapshot = HydrationTracker(entries: entries, dailyGoal: appliedSettings.dailyHydrationGoal).snapshot
        let summary = WidgetSummary(snapshot: snapshot, displayUnit: appliedSettings.displayUnit,
                                    generatedAt: now, day: day, calendar: calendar)
        guard summary.isValid(at: now, calendar: calendar) else { return .unavailable }
        return .available(summary)
    }
}

nonisolated extension WidgetSummary {
    init(snapshot: HydrationSnapshot, displayUnit: LiquidUnit, generatedAt: Date,
         day: DateInterval, calendar: Calendar) {
        schemaVersion = 1
        self.generatedAt = generatedAt.timeIntervalSince1970
        dayStart = day.start.timeIntervalSince1970
        dayEnd = day.end.timeIntervalSince1970
        calendarIdentifier = String(describing: calendar.identifier)
        timeZoneIdentifier = calendar.timeZone.identifier
        self.displayUnit = displayUnit.persistenceIdentifier
        goalMillilitres = VolumeCalculation.baseValue(from: snapshot.goalVolume)
        hydrationMillilitres = snapshot.totalHydrationVolume.map(VolumeCalculation.baseValue)
        remainingMillilitres = snapshot.remainingHydrationVolume.map(VolumeCalculation.baseValue)
        progressFraction = snapshot.hydrationProgress
    }

}
