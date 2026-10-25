import Foundation
@preconcurrency import UserNotifications
import Testing
@testable import SuperPooper

/// The app-state layer on in-memory services: the same calls menus and notification actions make.
@MainActor
struct AppModelTests {
    private func makeModel() throws -> AppModel {
        try #require(PreviewModel.make()).model
    }

    @Test func habitMarksGoThroughTheRepository() async throws {
        let model = try makeModel()
        let today = model.context().today
        await model.perform(.partial, on: "Выпить воды 💧")
        let habit = try #require(model.task(named: "Выпить воды 💧"))
        #expect(habit.completeInstances.contains(today))
        #expect(habit.partialInstances.contains(today))
        await model.perform(.unmark, on: "Выпить воды 💧")
        #expect(model.task(named: "Выпить воды 💧")?.completeInstances.contains(today) == false)
    }

    @Test func skipTodayHidesTheHabitWithoutWriting() async throws {
        let model = try makeModel()
        let before = try #require(model.task(named: "Выпить воды 💧"))
        await model.perform(.skipToday, on: "Выпить воды 💧")
        #expect(model.dayState.skipped == ["Выпить воды 💧"])
        #expect(model.plan(at: model.clock.now).item(named: "Выпить воды 💧") == nil)
        #expect(model.task(named: "Выпить воды 💧") == before)
    }

    /// "Not today" in the pool menu takes a task out of today without writing; it stays this week.
    @Test func notTodayFromTheMenuPostponesTheTask() async throws {
        let model = try makeModel()
        let before = try #require(model.task(named: "Повесить полку"))
        await model.perform(.notToday, on: "Повесить полку")
        #expect(model.dayState.postponed == ["Повесить полку"])
        #expect(model.plan(at: model.clock.now).item(named: "Повесить полку") == nil)
        #expect(model.task(named: "Повесить полку") == before)
        #expect(model.config.actions.menus["taskContext"]?.contains(.notToday) == true)
        #expect(model.config.actions.menus["taskContext"]?.contains(.archive) == false)
    }

    @Test func aNewHabitIsShownInTodayByDefault() throws {
        let model = try makeModel()
        #expect(model.newHabitDraft().changes.contains(.showInToday(true)))
    }

    /// "New in inbox" adds a reminder to the inbox list by its title, or says the list is missing.
    @Test func newInInboxAddsAReminderToTheInboxList() throws {
        let inbox = InboxRecorder(lists: ["📥 Inbox"])
        let model = try #require(PreviewModel.make(reminders: inbox)).model
        #expect(model.addToInbox("  Купить хлеб "))
        #expect(inbox.added == [InboxRecorder.Added(title: "Купить хлеб", list: "📥 inbox")])
        #expect(!model.addToInbox("   "))
        let missing = try #require(PreviewModel.make(reminders: InboxRecorder(lists: []))).model
        #expect(!missing.addToInbox("Купить хлеб"))
        #expect(missing.banners.current?.style == .problem)
    }

    /// Links order tasks but never prevent checking one off.
    @Test func aTaskAfterAnUnfinishedOneCanStillBeChecked() async throws {
        let model = try makeModel()
        #expect(model.plan(at: model.clock.now).item(named: "Повесить полку")?.isBlocked == true)
        await model.perform(.done, on: "Повесить полку")
        #expect(model.task(named: "Повесить полку")?.status == .done)
    }

    @Test func doneAndUnmarkCheckAndUncheckARegularTask() async throws {
        let model = try makeModel()
        let today = model.context().today
        await model.perform(.done, on: "Позвонить в банк")
        #expect(model.task(named: "Позвонить в банк")?.status == .done)
        #expect(model.task(named: "Позвонить в банк")?.completedDate == today)
        await model.perform(.unmark, on: "Позвонить в банк")
        #expect(model.task(named: "Позвонить в банк")?.status == .thisWeek)
        #expect(model.task(named: "Позвонить в банк")?.completedDate == nil)
    }

    /// Settings and the day keep pointing at a renamed habit: its place in the list and the routine, Skip today.
    @Test func renamingAHabitKeepsItsOrderRoutineAndSkip() async throws {
        let model = try makeModel()
        let name = "Выпить воды 💧"
        model.updateSettings {
            $0.habits.order = ["Медитация 🧘", name]
            $0.habits.morningRoutine = [name]
        }
        await model.perform(.skipToday, on: name)
        #expect(await model.rename(name, to: "Вода 💧"))
        #expect(model.settings.habits.order == ["Медитация 🧘", "Вода 💧"])
        #expect(model.settings.habits.morningRoutine == ["Вода 💧"])
        #expect(model.dayState.skipped == ["Вода 💧"])
    }

    /// A vault that cannot be read this once (bookmark not resolved in the background, no access) must not
    /// wipe the notifications and the widgets: they keep the last known tasks.
    @Test func aFailedScanKeepsTheWidgetSnapshot() async throws {
        let model = try makeModel()
        await model.sync(announce: false)
        let before = try #require(model.services.snapshotStore.load()).tasks.count
        #expect(before > 0)
        let repository = try #require(model.services.tasks as? InMemoryTaskRepository)
        await repository.failScans(with: CocoaError(.fileReadNoPermission))
        await model.sync(announce: false)
        #expect(model.services.snapshotStore.load()?.tasks.count == before)
    }

    /// A setting changed a moment before a sync is not undone by the older copy in the vault note.
    @Test func aSettingChangedJustBeforeASyncStays() async throws {
        let model = try makeModel()
        let root = try await model.services.vault.withRoot { $0 }
        try FileManager.default.createDirectory(at: root.appendingPathComponent("TaskNotes/Tasks"), withIntermediateDirectories: true)
        await model.sync(announce: false)
        #expect(await model.services.settingsNote.read() != nil)
        model.updateSettings { $0.timeline.hoursBefore = 5 }
        await model.sync(announce: false)
        #expect(model.settings.timeline.hoursBefore == 5)
    }

    /// Two plans in a row (a sync, then a mark): the newer one is what stays scheduled, even when the older one is
    /// slower to reach the notification center.
    @Test func theNewestNotificationPlanWins() async throws {
        let recorder = RecordingNotifications()
        let model = try #require(PreviewModel.make(notifications: recorder)).model
        await model.publishDerivedState()
        await model.perform(.done, on: "Забрать посылку")
        await model.waitForNotifications()
        try await Task.sleep(for: .milliseconds(600))
        #expect(await recorder.calls > 0)
        #expect(await !recorder.lastPlanned.contains { $0.taskName == "Забрать посылку" })
    }

    /// A sync asked for while another one runs (pull to refresh at launch, a new folder chosen) is not lost: the
    /// vault is read once more after the running sync.
    @Test func aSyncAskedForDuringASyncRunsAfterIt() async throws {
        let model = try makeModel()
        let repository = try #require(model.services.tasks as? InMemoryTaskRepository)
        await repository.slowScans(by: 0.3)
        async let first: Void = model.sync(announce: false)
        try await Task.sleep(for: .milliseconds(100))
        await model.sync(announce: true)
        await first
        #expect(await repository.scanCount == 2)
    }

    /// Lists switched quickly: an older read of the reminders that ends last must not bring back the old lists.
    @Test func theNewestReminderListsWin() async throws {
        let model = try #require(PreviewModel.make(reminders: ListedReminders())).model
        model.updateSettings { $0.sources.reminderListIDs = ["old"] }
        async let older: Void = model.refreshCalendarSources()
        try await Task.sleep(for: .milliseconds(50))
        model.updateSettings { $0.sources.reminderListIDs = ["new"] }
        await model.refreshCalendarSources()
        await older
        #expect(model.reminders.map(\.listID) == ["new"])
    }

    /// The widget keeps showing the next hours from one snapshot, past the day boundary too: tomorrow's early
    /// reminders are in it.
    @Test func theWidgetSnapshotReachesPastTheDayBoundary() async throws {
        let model = try #require(PreviewModel.make(reminders: EarlyReminder())).model
        await model.refreshCalendarSources()
        await model.publishDerivedState()
        let reminders = try #require(model.services.snapshotStore.load()).reminders
        #expect(reminders.map(\.title) == ["Early"])
    }

    /// "+" pressed while a slow sync reads the vault: the new task does not vanish when the sync finishes.
    @Test func aTaskCreatedDuringASyncStays() async throws {
        let model = try makeModel()
        let repository = try #require(model.services.tasks as? InMemoryTaskRepository)
        await repository.slowScans(by: 0.3)
        async let running: Void = model.sync(announce: false)
        try await Task.sleep(for: .milliseconds(100))
        let created = await model.create(NoteDraft(status: .thisWeek), named: "Новая во время синка")
        await running
        #expect(created == "Новая во время синка")
        #expect(model.task(named: "Новая во время синка") != nil)
    }

    /// Two quick taps on a habit's day: the second one sees the first one's mark (Done, then back to none),
    /// instead of deciding from the same old state.
    @Test func twoQuickTapsOnAHabitDayGoThereAndBack() async throws {
        let model = try makeModel()
        let today = model.context().today
        async let first: Void = model.cycleHabit("Выпить воды 💧", on: today)
        async let second: Void = model.cycleHabit("Выпить воды 💧", on: today)
        _ = await (first, second)
        let habit = try #require(model.task(named: "Выпить воды 💧"))
        #expect(HabitInstances(task: habit).mark(on: today) == nil)
    }

    @Test func archiveAndDelete() async throws {
        let model = try makeModel()
        await model.perform(.archive, on: "Сдать отчёт")
        #expect(model.archivedTasks.map(\.name) == ["Сдать отчёт"])
        await model.perform(.delete, on: "Сдать отчёт")
        #expect(model.task(named: "Сдать отчёт") == nil)
    }

    @Test func manualOrderIsKeptAndReset() throws {
        let model = try makeModel()
        let auto = model.plan(at: model.clock.now).pool.map(\.id)
        let manual = Array(auto.reversed())
        model.setManualOrder(manual)
        let ordered = model.plan(at: model.clock.now).pool.map(\.id)
        #expect(ordered != auto)
        model.resetOrder()
        #expect(model.plan(at: model.clock.now).pool.map(\.id) == auto)
    }

    /// A notification left over from yesterday must not mark today.
    @Test func notificationActionForAnotherDayIsIgnored() async throws {
        let model = try makeModel()
        let today = model.context().today
        await model.perform(.done, on: "Выпить воды 💧", day: today.adding(days: -1))
        #expect(model.task(named: "Выпить воды 💧")?.completeInstances.contains(today) == false)
        await model.perform(.done, on: "Выпить воды 💧", day: today)
        #expect(model.task(named: "Выпить воды 💧")?.completeInstances.contains(today) == true)
    }

    @Test func overlappingSyncsRunOnce() async throws {
        let model = try makeModel()
        async let first: Void = model.sync(announce: false)
        async let second: Void = model.sync(announce: false)
        _ = await (first, second)
        #expect(model.hasLoaded)
        #expect(model.runningSync == nil)
    }
}

/// Notifications that remember the last plan; the first plan takes a while to arrive (a slow notification center).
private actor RecordingNotifications: NotificationScheduling {
    private(set) var lastPlanned: [PlannedNotification] = []
    private(set) var calls = 0

    nonisolated func access() async -> SourceAccess { .granted }
    nonisolated func requestAccess() async -> Bool { true }
    nonisolated func registerCategories(_ registry: ActionRegistry, habitActionsEnabled: Bool) {}

    func sync(planned: [PlannedNotification], stillValid: [PlannedNotification], now immediate: [PlannedNotification]) async {
        calls += 1
        // The real center does not stop when the task is cancelled: a wait that ignores cancellation.
        if calls == 1 {
            await withCheckedContinuation { done in DispatchQueue.global().asyncAfter(deadline: .now() + 0.4) { done.resume() } }
        }
        lastPlanned = planned
    }

    func removeAll() async { lastPlanned = [] }
    nonisolated func restore(_ notification: UNNotification) async {}
}

/// Reminders of the asked lists; the "old" list takes a while to read.
private struct ListedReminders: RemindersRepository {
    var access: SourceAccess { .granted }
    func requestAccess() async -> Bool { true }
    func lists() -> [SourceCollection] { [] }
    func setCompleted(_ completed: Bool, reminderID: String) throws {}
    func add(_ title: String, toListTitled listTitle: String) throws {}

    func reminders(from start: Date, to end: Date, listIDs: [String]) async -> [ReminderItem] {
        if listIDs == ["old"] {
            await withCheckedContinuation { done in DispatchQueue.global().asyncAfter(deadline: .now() + 0.4) { done.resume() } }
        }
        return listIDs.map { ReminderItem(id: $0, title: $0, due: start, listID: $0, listTitle: $0, colorHex: "#000000", isCompleted: false) }
    }
}

/// One reminder an hour after the end of the logical day.
private struct EarlyReminder: RemindersRepository {
    var access: SourceAccess { .granted }
    func requestAccess() async -> Bool { true }
    func lists() -> [SourceCollection] { [] }
    func setCompleted(_ completed: Bool, reminderID: String) throws {}
    func add(_ title: String, toListTitled listTitle: String) throws {}

    func reminders(from start: Date, to end: Date, listIDs: [String]) async -> [ReminderItem] {
        let due = PreviewSamples.context.dayEnd.addingTimeInterval(3600)
        return [ReminderItem(id: "early", title: "Early", due: due, listID: "list", listTitle: "List", colorHex: "#000000", isCompleted: false)]
    }
}

/// Records reminders added to a list; lists that are not there fail like in EventKit.
private final class InboxRecorder: RemindersRepository, @unchecked Sendable {
    struct Added: Equatable {
        let title: String
        let list: String
    }

    let listTitles: [String]
    private(set) var added: [Added] = []

    init(lists: [String]) { listTitles = lists }

    var access: SourceAccess { .granted }
    func requestAccess() async -> Bool { true }
    func lists() -> [SourceCollection] { [] }
    func reminders(from start: Date, to end: Date, listIDs: [String]) async -> [ReminderItem] { [] }
    func setCompleted(_ completed: Bool, reminderID: String) throws {}

    func add(_ title: String, toListTitled listTitle: String) throws {
        guard listTitles.contains(where: { $0.isSameNoteName(as: listTitle) }) else { throw RemindersError.listNotFound(listTitle) }
        added.append(Added(title: title, list: listTitle))
    }
}
