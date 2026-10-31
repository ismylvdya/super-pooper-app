import Foundation
@preconcurrency import UserNotifications
import Testing
@testable import SuperPooperApp

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
    }

    @Test func aNewHabitIsShownInTodayByDefault() throws {
        let model = try makeModel()
        #expect(model.newHabitDraft().changes.contains(.showInToday(true)))
    }

    /// Links order tasks but never prevent checking one off.
    @Test func aTaskAfterAnUnfinishedOneCanStillBeChecked() async throws {
        let model = try makeModel()
        #expect(model.plan(at: model.clock.now).item(named: "Повесить полку")?.isBlocked == true)
        await model.perform(.done, on: "Повесить полку")
        await model.loadFiledTasks()
        #expect(model.filedTasks.first { $0.name == "Повесить полку" }?.status == .done)
    }

    /// The Done list's count sees a task done just now, before the folder is read again.
    @Test func theDoneListCountsATaskDoneJustNow() async throws {
        let model = try makeModel()
        let done = TaskListFilter(statuses: [.done])
        let before = model.listContents(done, query: "").count
        await model.perform(.done, on: "Позвонить в банк")
        #expect(model.listContents(done, query: "").count == before + 1)
    }

    /// A task marked done goes to the done folder at once, with its date; the Done list reads it from there.
    @Test func aDoneTaskGoesToTheDoneFolderAtOnce() async throws {
        let model = try makeModel()
        let today = model.context().today
        await model.perform(.done, on: "Позвонить в банк")
        #expect(model.task(named: "Позвонить в банк") == nil)
        await model.loadFiledTasks()
        let filed = try #require(model.filedTasks.first { $0.name == "Позвонить в банк" })
        #expect(filed.status == .done && filed.completedDate == today)
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

    /// A rename reaches today's Not today list and the manual order of the pool too.
    @Test func renamingAPostponedTaskKeepsItsPlaceInTheDay() async throws {
        let model = try makeModel()
        let name = "Сдать отчёт"
        model.postpone(name)
        model.setManualOrder(["Позвонить в банк", name])
        #expect(await model.rename(name, to: "Отчёт"))
        #expect(model.dayState.postponed == ["Отчёт"])
        #expect(model.dayState.manualOrder == ["Позвонить в банк", "Отчёт"])
        #expect(model.postponedTasks.map(\.name) == ["Отчёт"])
    }

    /// A drag in This week into another group: the new order at once, the new part of the day written to the task.
    @Test func aReviewDragIntoAnotherGroupSetsThePartOfTheDay() async throws {
        let model = try makeModel()
        let order = ["Сдать отчёт", "Позвонить в банк"]
        model.applyReviewMove(ReviewGroups.Move(order: order, regrouped: ["Сдать отчёт": .evening]))
        #expect(model.dayState.manualOrder == order)
        await model.pendingEdits["Сдать отчёт"]?.value
        #expect(model.task(named: "Сдать отчёт")?.habit.timeOfDay == .evening)
        #expect(model.task(named: "Позвонить в банк")?.habit.timeOfDay == nil)
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
    /// On the store the app uses: the settings file next to the tasks folder.
    @Test func aSettingChangedJustBeforeASyncStays() async throws {
        let model = try makeModel()
        let root = try await model.services.vault.withRoot { $0 }
        try FileManager.default.createDirectory(at: root.appendingPathComponent("TaskNotes/Tasks"), withIntermediateDirectories: true)
        await model.sync(announce: false)
        let file = root.appendingPathComponent("TaskNotes").appendingPathComponent(model.config.rules.vault.settingsFile)
        #expect(FileManager.default.fileExists(atPath: file.path))
        model.updateSettings { $0.timeline.hoursBefore = 5 }
        await model.sync(announce: false)
        #expect(model.settings.timeline.hoursBefore == 5)
        let written = try JSONDecoder.store.decode(SyncedSettings.self, from: Data(contentsOf: file))
        #expect(written == SyncedSettings(model.settings))
    }

    /// Two plans in a row (a sync, then a mark): the newer one is what stays scheduled, even when the older one is
    /// slower to reach the notification center.
    @Test func theNewestNotificationPlanWins() async throws {
        let slowCenter = AsyncGate()
        let recorder = RecordingNotifications(firstSync: slowCenter)
        let model = try #require(PreviewModel.make(notifications: recorder)).model
        await model.publishDerivedState()
        await model.perform(.done, on: "Забрать посылку")
        await slowCenter.arrived()
        await slowCenter.open()
        await model.waitForNotifications()
        #expect(await recorder.calls > 1)
        #expect(await !recorder.lastPlanned.contains { $0.taskName == "Забрать посылку" })
    }

    /// A sync asked for while another one runs (pull to refresh at launch, a new folder chosen) is not lost: the
    /// vault is read once more after the running sync.
    @Test func aSyncAskedForDuringASyncRunsAfterIt() async throws {
        let model = try makeModel()
        let repository = try #require(model.services.tasks as? InMemoryTaskRepository)
        let slowScan = AsyncGate()
        await repository.holdScans(at: slowScan)
        async let first: Void = model.sync(announce: false)
        await slowScan.arrived()
        let second = Task { await model.sync(announce: true) }
        while model.syncAgain == nil { await Task.yield() }
        await slowScan.open()
        await first
        await second.value
        #expect(await repository.scanCount == 2)
    }

    /// Lists switched quickly: an older read of the reminders that ends last must not bring back the old lists.
    @Test func theNewestReminderListsWin() async throws {
        let reminders = ListedReminders()
        let model = try #require(PreviewModel.make(reminders: reminders)).model
        model.updateSettings { $0.sources.reminderListIDs = ["old"] }
        async let older: Void = model.refreshCalendarSources()
        await reminders.oldList.arrived()
        model.updateSettings { $0.sources.reminderListIDs = ["new"] }
        await model.refreshCalendarSources()
        await reminders.oldList.open()
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
        let slowScan = AsyncGate()
        await repository.holdScans(at: slowScan)
        async let running: Void = model.sync(announce: false)
        await slowScan.arrived()
        let created = await model.create(NoteDraft(status: .thisWeek), named: "Новая во время синка")
        await slowScan.open()
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
