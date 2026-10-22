import Foundation
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

    @Test func blockedTaskIsNotCheckedAndExplains() async throws {
        let model = try makeModel()
        await model.toggle("Повесить полку")
        #expect(model.task(named: "Повесить полку")?.status == .thisWeek)
        #expect(model.banners.current?.text.contains("Позвонить в банк") == true)
    }

    @Test func toggleChecksAndUnchecksARegularTask() async throws {
        let model = try makeModel()
        let today = model.context().today
        await model.toggle("Позвонить в банк")
        #expect(model.task(named: "Позвонить в банк")?.status == .done)
        #expect(model.task(named: "Позвонить в банк")?.completedDate == today)
        await model.toggle("Позвонить в банк")
        #expect(model.task(named: "Позвонить в банк")?.status == .thisWeek)
        #expect(model.task(named: "Позвонить в банк")?.completedDate == nil)
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
