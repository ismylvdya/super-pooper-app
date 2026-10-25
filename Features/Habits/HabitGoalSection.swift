import SwiftUI

/// How missed days count: not at all, by allowed skips in a row, or by a weekly goal.
struct HabitGoalSection: View {
    @Environment(\.rules) private var rules
    let editor: TaskEditor

    private enum Kind: Hashable, CaseIterable { case none, skips, goal }

    private var options: HabitOptions { editor.task.habit }

    var body: some View {
        let kind = Self.kind(options.skipRule)
        PlateSection(header: "habitPage.goal", info: "info.habitPage.goal") {
            PlateRow(icon: .goal, title: "habitPage.goal.rule") {
                Picker("habitPage.goal.rule", selection: Binding(get: { kind }, set: set)) {
                    Text("habitPage.goal.none").tag(Kind.none)
                    if !options.harmful { Text("habitPage.goal.skips").tag(Kind.skips) }
                    Text("habitPage.goal.weekly").tag(Kind.goal)
                }
                .labelsHidden()
            }
            switch options.skipRule {
            case .none:
                EmptyView()
            case .missedDays(let allowed):
                PlateRow(icon: nil, title: "habitPage.goal.allowedSkips", indent: true) {
                    Stepper(String(allowed), value: Binding(get: { allowed }, set: { editor.apply([.allowedSkips($0)]) }),
                            in: 0...rules.habits.maxAllowedSkips)
                        .fixedSize()
                }
            case .weeklyGoal(let times):
                PlateRow(icon: nil, title: "habitPage.goal.timesAWeek", indent: true) {
                    Stepper(String(times), value: Binding(get: { times }, set: { editor.apply([.weeklyGoal($0)]) }),
                            in: 1...(Weekday.allCases.count * Int(options.unitsPerDay)))
                        .fixedSize()
                }
            }
        }
    }

    private func set(_ kind: Kind) {
        switch kind {
        case .none: editor.apply([.weeklyGoal(nil), .allowedSkips(nil)])
        case .skips: editor.apply([.weeklyGoal(nil), .allowedSkips(options.allowedSkips ?? rules.habits.defaultAllowedSkips)])
        case .goal: editor.apply([.allowedSkips(nil), .weeklyGoal(options.weeklyGoal ?? rules.habits.defaultWeeklyGoal)])
        }
    }

    private static func kind(_ rule: HabitSkipRule) -> Kind {
        switch rule {
        case .none: .none
        case .missedDays: .skips
        case .weeklyGoal: .goal
        }
    }
}
