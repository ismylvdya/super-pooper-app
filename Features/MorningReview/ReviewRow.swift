import ListEngineChumbulev
import SwiftUI

/// One row of the review, as the list engine draws it: the name (grey once done), the chips that only show something
/// (a habit, overdue, a problem) right of it, the parent's name over it, the started icon before it, and under it the
/// chips that change the task: High, the due date, the estimate, energy, pleasant, the status (`ListActionChip`).
@MainActor
struct ReviewRow {
    let model: AppModel
    let tokens: DesignTokens
    let icons: IconSet
    let rules: RulesConfig
    let chipOrder: [RowChipKind]
    /// Opens the exact date and time picker for the task of that name.
    let pickDue: (String) -> Void

    func content(_ item: DayItem) -> ListRowContent {
        let task = item.task
        let started = task.isStarted && !item.isDone
        return ListRowContent(title: task.name, chips: indicators(item),
                              icon: started ? .app(icons[.started]) : nil, iconColor: started ? ThemeColor(tokens.uiColor(.started)) : nil,
                              titleColor: item.isDone ? ThemeColor(tokens.uiColor(.secondaryText)) : nil,
                              actionChips: chips(item), overline: item.project)
    }

    /// The chips that only show something, in the pool's order (`RowChipKind.isIndicator`).
    private func indicators(_ item: DayItem) -> [ListChip] {
        RowChip.chips(for: item, order: chipOrder.filter(\.isIndicator)).map { chip in
            ListChip(kind: chip.kind.rawValue, content: .icon(.app(icons[chip.look.icon])),
                     color: ThemeColor(UIColor(tokens.color(of: chip.look, onFill: item.task.isHighPriority))))
        }
    }

    private func chips(_ item: DayItem) -> [ListActionChip] {
        let task = item.task
        var chips = [
            toggle(.high, isOn: task.isHighPriority, task: task) { [.highPriority(!$0.isHighPriority)] },
            due(task),
            estimate(task),
            // One feel: turning one on turns the other off.
            toggle(.needEnergy, isOn: task.feel == .needEnergy, task: task) { [.feel($0.feel == .needEnergy ? .neutral : .needEnergy)] },
            toggle(.pleasant, isOn: task.feel == .pleasant, task: task) { [.feel($0.feel == .pleasant ? .neutral : .pleasant)] },
        ]
        if !task.isHabit { chips.append(status(task)) }
        return chips
    }

    /// The new value is decided from the note as it is when the edit runs (two quick taps go there and back).
    private func toggle(_ look: ChipLook, isOn: Bool, task: TaskItem, changes: @escaping (TaskItem) -> [TaskEdit]) -> ListActionChip {
        ListActionChip(id: "\(look)", icon: .app(icons[look.icon]), color: ThemeColor(tokens.uiColor(look.tint ?? .secondaryText)),
                       isOn: isOn, action: .tap {
            Haptics.play(.select)
            Task { await model.edit(task.name, changes) }
        })
    }

    /// Today / Tomorrow / an exact date and time; the chosen one is checked, choosing it again removes the date. Today and
    /// Tomorrow are logical days, as the task page's chips.
    private func due(_ task: TaskItem) -> ListActionChip {
        let context = model.context()
        let selected = QuickDue.selection(of: task.due, context: context)
        var choices = QuickDue.allCases.map { chip in
            ListChoice(id: "\(chip)", title: L10n.string(chip.key), isOn: selected == chip) {
                Task { await model.setLocalDue(QuickDue.toggling(chip, due: task.due, context: context), of: task.name) }
            }
        }
        choices.append(ListChoice(id: "exact", title: L10n.string("review.due.exact"), isOn: task.due != nil && selected == nil) {
            pickDue(task.name)
        })
        return ListActionChip(id: "due", icon: .app(icons[.due]), text: task.due.map { DueText.format($0, context: context) },
                              isOn: task.due != nil, action: .menu(choices))
    }

    private func estimate(_ task: TaskItem) -> ListActionChip {
        ListActionChip(id: "estimate", icon: .app(icons[.estimate]), text: EstimateText.label(task.timeEstimate, rules: rules),
                       action: .menu(rules.timeEstimates.map { option in
            ListChoice(id: "\(option.minutes)", title: L10n.string(option.label), isOn: option.minutes == task.timeEstimate) {
                Task { await model.update(task.name, [.timeEstimate(option.minutes)]) }
            }
        }))
    }

    private func status(_ task: TaskItem) -> ListActionChip {
        ListActionChip(id: "status", icon: .app(icons[.status]), text: StatusText.title(task.status),
                       action: .menu(TaskStatus.reviewChoices.map { status in
            ListChoice(id: "\(status)", title: StatusText.title(status), isOn: status == task.status) {
                Task { _ = await model.setStatus(status, of: task.name) }
            }
        }))
    }
}

extension QuickDue {
    /// The day's name's String Catalog key, for a menu line of the engine.
    var key: String {
        switch self {
        case .today: "due.today"
        case .tomorrow: "due.tomorrow"
        }
    }
}
