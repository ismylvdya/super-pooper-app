import Foundation
import Observation

/// The app state as the screens see it: read-only state to render and intents to forward, nothing else. The work is done
/// by the parts behind it (`AppParts`): the tasks, the commands that change them, the day, the settings, Calendar and
/// Reminders, the sync and what is derived from all of it. What the user should hear about leaves as `AppEvent`s.
/// Screens use only the members of this façade, never `parts`.
@MainActor
@Observable
final class AppModel {
    let config: AppConfig
    @ObservationIgnored let parts: AppParts

    init(config: AppConfig, services: AppServices, appEvents: AppEventSink, clock: Clock, calendar: CalendarSource,
         delay: Delay = SleepDelay()) {
        self.config = config
        parts = AppParts(config: config, services: services, appEvents: appEvents, clock: clock, calendar: calendar, delay: delay)
    }

    // MARK: - State

    var clock: Clock { parts.day.clock }
    var calendar: Calendar { parts.day.calendar }
    var settings: AppSettings { parts.settings.settings }
    var dayState: DayState { parts.day.dayState }
    var tasks: [TaskItem] { parts.tasks.tasks }
    var filedTasks: [TaskItem] { parts.tasks.filedTasks }
    var fileProblems: [FileProblem] { parts.tasks.fileProblems }
    var conflictedNotes: [String] { parts.tasks.conflictedNotes }
    var chosenFolder: ChosenFolder { parts.tasks.chosenFolder }
    var vaultState: VaultState { parts.tasks.vaultState }
    var events: [CalendarEvent] { parts.sources.events }
    var reminders: [ReminderItem] { parts.sources.reminders }
    var access: SourceAccessState { parts.sources.access }
    var trashedNotes: [TrashedNote] { parts.trash.notes }
    var hasLoaded: Bool { parts.sync.hasLoaded }
    var isSyncing: Bool { parts.sync.isSyncing }

    /// The text of a note open on its page.
    func noteBody(_ name: String) -> NoteBody? { parts.texts.bodies[name] }

    // MARK: - Day

    func context(at date: Date? = nil) -> DayContext { parts.day.context(at: date) }

    /// Today (`dayOffset` 0) or another day browsed on Today, worked out once per change of its data and minute.
    func plan(at date: Date, dayOffset: Int = 0) -> DayPlan { parts.derived.plan(at: date, dayOffset: dayOffset) }

    var problemCount: Int { parts.derived.problemCount }
    var postponedTasks: [TaskItem] { parts.dayCommands.postponedTasks }

    func postpone(_ name: String) { parts.dayCommands.postpone(name) }
    func unpostpone(_ name: String) { parts.dayCommands.unpostpone(name) }
    func setManualOrder(_ names: [String]) { parts.dayCommands.setManualOrder(names) }
    func resetOrder() { parts.dayCommands.resetOrder() }
    func applyReviewMove(_ move: ReviewGroups.Move) { parts.dayCommands.applyReviewMove(move) }
    /// A drag between the pool and the timeline of any day; `slot`: a habit block's time as its note has it, when it comes
    /// from the timeline (a habit moves for that day only).
    func schedule(_ name: String, slot: LocalTime? = nil, at moment: Date) async {
        await parts.dayCommands.schedule(name, slot: slot, at: moment)
    }
    func unschedule(_ name: String, slot: LocalTime? = nil, poolOrder: [String], on day: LocalDate? = nil) async {
        await parts.dayCommands.unschedule(name, slot: slot, poolOrder: poolOrder, on: day)
    }
    func canDropOnTimeline(_ name: String, slot: LocalTime?, on day: LocalDate? = nil) -> Bool {
        parts.dayCommands.canPlaceOnTimeline(name, slot: slot, on: day)
    }
    func canDropInPool(_ name: String, slot: LocalTime?) -> Bool { parts.dayCommands.canSendToPool(name, slot: slot) }

    /// The morning review opens by itself once a day, on the first launch with a ready vault after onboarding, unless
    /// the app was opened for something else. True when it is to open now (it then counts as shown).
    func claimMorningReview(openedForSomethingElse: Bool) -> Bool {
        guard config.flags.morningReviewAutoOpen, settings.onboarding.completed, vaultState == .ready, !dayState.reviewShown,
              !openedForSomethingElse else { return false }
        parts.day.markReviewShown()
        return true
    }

    // MARK: - Settings

    func updateSettings(_ change: (inout AppSettings) -> Void) { parts.settings.update(change) }

    /// A change still waiting is written and followed now (the app goes to the background).
    func flushSettings() async { await parts.settings.flush() }

    /// The user's own picture for habit notifications (this device), or nil for the habit symbol.
    var notificationImageData: Data? { parts.picture.imageData }
    func setNotificationImage(_ data: Data?) async { await parts.picture.setImage(data) }
    func setNotificationPictureShown(_ isShown: Bool) { parts.picture.setShown(isShown) }
    func setNotificationPictureUsesHabitColor(_ usesColor: Bool) { parts.picture.setUsesHabitColor(usesColor) }

    // MARK: - Signature

    /// How long the app's signature has left; nil while it is far off or unknown (no plate).
    var signingCountdown: SigningCountdown? { parts.signing.countdown }
    func refreshSigning() { parts.signing.refresh() }

    // MARK: - Sync

    /// Full sync: the tasks, auto-promotion, Calendar and Reminders, then widgets and notifications. `announce` reports
    /// what changed (pull to refresh).
    func sync(announce: Bool) async { await parts.sync.sync(announce: announce) }
    func ensureLoaded() async { await parts.sync.ensureLoaded() }
    func syncWhenTheDayEnds() async { await parts.sync.syncWhenTheDayEnds() }
    func timeDidChange() async { await parts.sync.timeDidChange() }

    /// A vault folder is chosen (it may still be loading).
    var hasVault: Bool { parts.sync.hasVault }
    var vaultName: String? { parts.sync.vaultName }
    func selectVault(_ url: URL) async { await parts.sync.selectVault(url) }
}
