import SwiftUI

/// Edits a habit's repeat rule the way Apple Calendar does: frequency, interval, weekdays or the day of
/// the month, start and end. Every change is written to the note right away.
struct RecurrenceEditorSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.rules) private var rules
    let editor: TaskEditor
    @State private var draft: RecurrenceDraft?

    private var task: TaskNote { editor.task }

    var body: some View {
        let draft = self.draft ?? initialDraft
        PlateSection(header: "recurrenceEditor.header", info: "info.recurrenceEditor",
                     hint: Text(verbatim: RecurrenceText.describe(draft, calendar: model.calendar))) {
            PlateRow(icon: .recurrence, title: "recurrenceEditor.frequency") {
                Picker("recurrenceEditor.frequency", selection: edit(\.frequency)) {
                    ForEach(RecurrenceFrequency.allCases, id: \.self) { Text(LocalizedStringKey($0.titleKey)).tag($0) }
                }
                .labelsHidden()
            }
            PlateRow(icon: nil, title: "recurrenceEditor.interval", indent: true) {
                Stepper(L10n.format("recurrenceEditor.every", draft.interval, L10n.string(draft.frequency.unitKey)),
                        value: edit(\.interval), in: rules.limits.recurrenceInterval.ints)
            }
            if draft.frequency == .weekly { weekdayRow(draft) }
            if draft.frequency == .monthly { monthlyRows(draft) }
            PlateRow(icon: nil, title: "recurrenceEditor.starts", indent: true) {
                DatePicker("recurrenceEditor.starts", selection: Binding(
                    get: { draft.start.startDate(in: model.calendar) },
                    set: { date in change { $0.start = LocalDate(date, in: model.calendar) } }
                ), displayedComponents: .date).labelsHidden()
            }
            endRows(draft)
        }
    }

    // MARK: - Rows

    private func weekdayRow(_ draft: RecurrenceDraft) -> some View {
        let selected = draft.weekdays.isEmpty ? [draft.start.weekday] : draft.weekdays
        return HStack(spacing: tokens.space(.chipGap)) {
            ForEach(Weekday.allCases, id: \.self) { day in
                Button {
                    Haptics.play(.light)
                    change { value in
                        var days = selected
                        if days.contains(day) { if days.count > 1 { days.remove(day) } } else { days.insert(day) }
                        value.weekdays = days
                    }
                } label: {
                    Chip(text: day.name(.initial, in: model.calendar),
                         tint: tokens.color(.accent), isOn: selected.contains(day))
                }
                .buttonStyle(.borderless)
            }
        }
    }

    @ViewBuilder private func monthlyRows(_ draft: RecurrenceDraft) -> some View {
        PlateRow(icon: nil, title: "recurrenceEditor.monthlyDay", indent: true) {
            Picker("recurrenceEditor.monthlyDay", selection: edit(\.monthlyDay)) {
                ForEach(monthlyChoices(draft), id: \.self) { Text(monthlyTitle($0)).tag($0) }
            }
            .labelsHidden()
        }
        if case .dayOfMonth(let day) = draft.monthlyDay {
            PlateRow(icon: nil, title: "recurrenceEditor.dayNumber", indent: true) {
                Stepper(String(day), value: Binding(get: { day }, set: { value in change { $0.monthlyDay = .dayOfMonth(value) } }), in: 1...31)
            }
        }
    }

    @ViewBuilder private func endRows(_ draft: RecurrenceDraft) -> some View {
        PlateRow(icon: nil, title: "recurrenceEditor.ends", indent: true) {
            Picker("recurrenceEditor.ends", selection: Binding(
                get: { EndKind(draft.end) },
                set: { kind in change { $0.end = kind.end(after: draft.start, editing: rules.editing) } }
            )) {
                ForEach(EndKind.allCases, id: \.self) { Text(LocalizedStringKey($0.titleKey)).tag($0) }
            }
            .labelsHidden()
        }
        switch draft.end {
        case .never:
            EmptyView()
        case .until(let day):
            PlateRow(icon: nil, title: "recurrenceEditor.endDate", indent: true) {
                DatePicker("recurrenceEditor.endDate", selection: Binding(
                    get: { day.startDate(in: model.calendar) },
                    set: { date in change { $0.end = .until(LocalDate(date, in: model.calendar)) } }
                ), displayedComponents: .date).labelsHidden()
            }
        case .count(let count):
            PlateRow(icon: nil, title: "recurrenceEditor.endCount", indent: true) {
                Stepper(L10n.format("recurrenceEditor.times", count),
                        value: Binding(get: { count }, set: { value in change { $0.end = .count(value) } }), in: rules.limits.recurrenceCount.ints)
            }
        }
    }

    // MARK: - Editing

    private var initialDraft: RecurrenceDraft {
        let today = model.context().today
        if let rule = task.recurrence { return RecurrenceDraft(rule: rule, fallbackStart: today) }
        return RecurrenceDraft(start: today)
    }

    private func edit<Value>(_ keyPath: WritableKeyPath<RecurrenceDraft, Value>) -> Binding<Value> {
        Binding(get: { (draft ?? initialDraft)[keyPath: keyPath] },
                set: { value in change { $0[keyPath: keyPath] = value } })
    }

    private func change(_ edit: (inout RecurrenceDraft) -> Void) {
        var updated = draft ?? initialDraft
        edit(&updated)
        draft = updated
        let raw = updated.raw
        guard raw != task.recurrenceRaw else { return }
        editor.apply([.recurrence(raw)])
    }

    private func monthlyChoices(_ draft: RecurrenceDraft) -> [RecurrenceDraft.MonthlyDay] {
        let start = draft.start
        var choices: [RecurrenceDraft.MonthlyDay] = [.dayOfMonth(start.day), .lastDayOfMonth,
                                                      .weekday(ordinal: (start.day - 1) / 7 + 1, weekday: start.weekday)]
        if start.day + 7 > LocalDate.daysInMonth(year: start.year, month: start.month) {
            choices.append(.weekday(ordinal: -1, weekday: start.weekday))
        }
        if !choices.contains(draft.monthlyDay) { choices.insert(draft.monthlyDay, at: 0) }
        if case .dayOfMonth = draft.monthlyDay { choices.removeAll { if case .dayOfMonth = $0 { $0 != draft.monthlyDay } else { false } } }
        return choices
    }

    private func monthlyTitle(_ day: RecurrenceDraft.MonthlyDay) -> LocalizedStringKey {
        switch day {
        case .dayOfMonth: return "recurrenceEditor.dayOfMonth"
        case .lastDayOfMonth: return "recurrenceEditor.lastDay"
        case .weekday(let ordinal, let weekday):
            return LocalizedStringKey(RecurrenceText.ordinalWeekday(ordinal, weekday.name(.full, in: model.calendar)))
        }
    }
}

private enum EndKind: CaseIterable {
    case never, until, count

    init(_ end: RecurrenceDraft.End) {
        switch end {
        case .never: self = .never
        case .until: self = .until
        case .count: self = .count
        }
    }

    var titleKey: String {
        switch self {
        case .never: "recurrenceEditor.end.never"
        case .until: "recurrenceEditor.end.until"
        case .count: "recurrenceEditor.end.count"
        }
    }

    func end(after start: LocalDate, editing: RulesConfig.Editing) -> RecurrenceDraft.End {
        switch self {
        case .never: .never
        case .until: .until(start.adding(days: editing.repeatUntilDays))
        case .count: .count(editing.repeatCount)
        }
    }
}

private extension RecurrenceFrequency {
    static let allCases: [RecurrenceFrequency] = [.daily, .weekly, .monthly, .yearly]

    var titleKey: String {
        switch self {
        case .daily: "recurrenceEditor.freq.daily"
        case .weekly: "recurrenceEditor.freq.weekly"
        case .monthly: "recurrenceEditor.freq.monthly"
        case .yearly: "recurrenceEditor.freq.yearly"
        }
    }

    var unitKey: String {
        switch self {
        case .daily: "recurrenceEditor.unit.days"
        case .weekly: "recurrenceEditor.unit.weeks"
        case .monthly: "recurrenceEditor.unit.months"
        case .yearly: "recurrenceEditor.unit.years"
        }
    }
}
