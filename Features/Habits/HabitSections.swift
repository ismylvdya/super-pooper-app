import SwiftUI

/// The sections of a habit page (also used by the new-habit draft, which has no history yet).
/// The description (the note body) sits right under the history.
struct HabitSections: View {
    let editor: TaskEditor

    var body: some View {
        if !editor.isDraft {
            HabitHistorySection(habit: editor.task)
            TaskNoteSection(taskName: editor.task.name, header: "habitPage.description", isCompact: true)
            HabitStatsSection(habit: editor.task)
        }
        HabitOptionsSection(editor: editor)
        HabitGoalSection(editor: editor)
        RecurrenceEditorSection(editor: editor)
        HabitRemindersSection(editor: editor)
    }
}

/// Weeks of the habit back to its first marked day; the newest week is at the bottom and visible first.
/// Tap a day to cycle its mark, long press to pick one. Pulling down at the top adds older weeks
/// (until the page is left). The top edge always fades, the bottom one while newer weeks are below.
struct HabitHistorySection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.rules) private var rules
    let habit: TaskNote
    @State private var addedWeeks = 0
    @State private var isAtBottom = true

    var body: some View {
        let today = model.context().today
        let weeks = HabitGrid.weekCount(for: habit, today: today, calendar: model.calendar,
                                        minimumWeeks: rules.habits.historyMinimumWeeks,
                                        extraWeeks: rules.habits.historyExtraWeeks) + addedWeeks
        let grid = HabitGrid(task: habit, weekCount: weeks, today: today, calendar: model.calendar)
        let metrics = HabitDotMetrics(dot: tokens.size(.habitDot), ringRatio: tokens.size(.habitRingRatio))
        let inner = tokens.space(.plateInner)
        let shape = RoundedRectangle(cornerRadius: tokens.radius(.plate), style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Text("habitPage.history").font(tokens.font(.sectionHeader)).foregroundStyle(tokens.color(.tertiaryText))
                InfoButton(text: "info.habitPage.history", tint: tokens.color(.tertiaryText))
            }
            .padding(.horizontal, inner)
            .padding(.bottom, tokens.space(.headerToPlate))
            VStack(spacing: 0) {
                WeekdayHeader(metrics: metrics).padding(.top, inner)
                ScrollView {
                    HabitGridView(grid: grid, color: tokens.habitColor(habit), metrics: metrics, onTap: { day in
                        Haptics.play(.light)
                        Task { await model.cycleHabit(habit.name, on: day) }
                    }) { day in
                        HabitDayMenu(habit: habit, day: day, showsDate: true)
                    }
                    .frame(maxWidth: .infinity)
                }
                .contentMargins(.vertical, tokens.size(.fadeHeight) / 2, for: .scrollContent)
                // The newest week is visible first; weeks added on top keep the scroll position.
                .defaultScrollAnchor(.bottom, for: .initialOffset)
                .scrollIndicators(.hidden)
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.visibleRect.maxY >= geometry.contentSize.height - 1
                } action: { _, atBottom in isAtBottom = atBottom }
                .pullToExtend(icon: .olderWeeks) {
                    Haptics.play(.medium)
                    addedWeeks += rules.habits.historyPullWeeks
                }
                .overlay(alignment: .top) { EdgeFade(edge: .top, color: tokens.color(.plateBackground)) }
                .overlay(alignment: .bottom) {
                    EdgeFade(edge: .bottom, color: tokens.color(.plateBackground)).opacity(isAtBottom ? 0 : 1)
                }
                .frame(maxHeight: tokens.size(.habitHistoryMaxHeight))
            }
            .background(tokens.color(.plateBackground), in: shape)
            .clipShape(shape)
            Text("habitPage.history.hint")
                .font(tokens.font(.hint))
                .foregroundStyle(tokens.color(.secondaryText))
                .padding(.horizontal, inner)
                .padding(.top, tokens.space(.hintToPlate))
        }
    }
}

/// Color, harmful, Today, part of the day, twice a day.
struct HabitOptionsSection: View {
    @Environment(\.tokens) private var tokens
    let editor: TaskEditor

    private var options: HabitOptions { editor.task.habit }

    var body: some View {
        PlateSection(header: "habitPage.options", info: "info.habitPage.options") {
            toggle(.today, "habitPage.showInToday", "info.habitPage.showInToday", \.showInToday, TaskFieldChange.showInToday)
            PlateRow(icon: .colors, title: "habitPage.color") {
                ColorPicker("habitPage.color", selection: Binding(
                    get: { tokens.habitColor(editor.task) },
                    set: { color in editor.apply([.habitColor(UIColor(color).hexString)]) }
                ), supportsOpacity: false)
                .labelsHidden()
            }
            toggle(.harmful, "habitPage.harmful", "info.habitPage.harmful", \.harmful, TaskFieldChange.harmful)
            PlateRow(icon: .timeOfDay, title: "habitPage.timeOfDay", info: "info.habitPage.timeOfDay") {
                Picker("habitPage.timeOfDay", selection: Binding(
                    get: { options.timeOfDay },
                    set: { editor.apply([.timeOfDay($0)]) }
                )) {
                    Text("habitPage.timeOfDay.any").tag(HabitTimeOfDay?.none)
                    ForEach(HabitTimeOfDay.allCases, id: \.self) { Text(LocalizedStringKey(String("habitPage.timeOfDay.") + $0.rawValue)).tag(HabitTimeOfDay?.some($0)) }
                }
                .labelsHidden()
            }
            toggle(.markTwice, "habitPage.twiceADay", "info.habitPage.twiceADay", \.twiceADay, TaskFieldChange.twiceADay)
            if options.twiceADay {
                PlateRow(icon: nil, title: "habitPage.twiceCountsDouble", indent: true) {
                    Toggle("habitPage.twiceCountsDouble", isOn: binding(\.twiceCountsDouble, TaskFieldChange.twiceCountsDouble)).labelsHidden()
                }
            }
        }
    }

    private func toggle(_ icon: Icon, _ title: LocalizedStringKey, _ info: LocalizedStringKey,
                        _ keyPath: KeyPath<HabitOptions, Bool>, _ change: @escaping (Bool) -> TaskFieldChange) -> some View {
        PlateRow(icon: icon, title: title, info: info) {
            Toggle(title, isOn: binding(keyPath, change)).labelsHidden()
        }
    }

    private func binding(_ keyPath: KeyPath<HabitOptions, Bool>, _ change: @escaping (Bool) -> TaskFieldChange) -> Binding<Bool> {
        Binding(get: { options[keyPath: keyPath] }, set: { editor.apply([change($0)]) })
    }
}

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
                            in: 1...(options.unitsPerDay > 1 ? 14 : 7))
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
