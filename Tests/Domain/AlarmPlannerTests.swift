import Foundation
import Testing
@testable import SuperPooperApp

struct AlarmPlannerTests {
    private let sounds = [RulesConfig.Alarms.Sound(id: "system", title: "", file: nil),
                          RulesConfig.Alarms.Sound(id: "chime", title: "", file: "chime.wav")]
    private var planner: AlarmPlanner { AlarmPlanner(sounds: sounds, defaultSound: "chime") }
    private let moment = Date(timeIntervalSince1970: 1000)

    private func note(_ kind: PlannedNotification.Kind, _ name: String, slot: String) -> PlannedNotification {
        PlannedNotification(id: name + slot, kind: kind, title: name, fireDate: moment, taskName: name, day: LocalDate("2026-11-04"),
                            key: name + slot, slot: LocalTime(slot))
    }

    private func habit(alarmAt time: String, sound: String? = nil) -> TaskItem {
        var item = TaskItem(id: TaskID("h"), name: "Water", status: .habit)
        item.reminderTimes = [LocalTime("09:00"), LocalTime("18:00")]
        item.alarms = [TimeAlarm(time: LocalTime(time), sound: sound)]
        return item
    }

    @Test func onlyTheHabitsMarkedTimeRings() {
        let planned = [note(.habit, "Water", slot: "09:00"), note(.habit, "Water", slot: "18:00")]
        let marked = planner.marking(planned, tasks: [habit(alarmAt: "18:00")])
        #expect(marked.map(\.hasAlarm) == [false, true], "its notification goes silent, the other keeps its sound")
        #expect(planner.alarms(planned, tasks: [habit(alarmAt: "18:00")]).count == 1)
    }

    @Test func aTasksAlarmFollowsWhateverTimeItHas() {
        var task = TaskItem(id: TaskID("t"), name: "Dentist", status: .thisWeek)
        task.alarms = [TimeAlarm()]
        #expect(planner.alarms([note(.task, "Dentist", slot: "14:30")], tasks: [task]).count == 1)
    }

    @Test func theSoundIsItsOwnOrTheSettings() {
        let planned = [note(.habit, "Water", slot: "09:00")]
        #expect(planner.alarms(planned, tasks: [habit(alarmAt: "09:00")]).first?.soundFile == "chime.wav")
        #expect(planner.alarms(planned, tasks: [habit(alarmAt: "09:00", sound: "system")]).first?.soundFile == nil)
    }

    @Test func anotherSoundOrMomentIsAnotherAlarm() {
        let planned = [note(.habit, "Water", slot: "09:00")]
        #expect(planner.alarms(planned, tasks: [habit(alarmAt: "09:00")]).first?.id
            != planner.alarms(planned, tasks: [habit(alarmAt: "09:00", sound: "system")]).first?.id)
    }

    @Test func editingATimeTakesItsAlarmAlongAndRemovingItDropsIt() {
        let alarms = [TimeAlarm(time: LocalTime("09:00"), sound: "chime")]
        let old = [LocalTime("09:00"), LocalTime("18:00")]
        #expect(alarms.following(times: old, to: [LocalTime("10:00"), LocalTime("18:00")]) == [TimeAlarm(time: LocalTime("10:00"), sound: "chime")])
        #expect(alarms.following(times: old, to: [LocalTime("18:00")]).isEmpty)
    }
}
