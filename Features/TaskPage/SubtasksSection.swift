import ListEngineChumbulev
import SwiftUI

/// Subtasks: each is a task of its own that names this one as its parent; theirs stand under them. A list of the list
/// engine, as a list of the Lists tab: a tap opens one, a long press its menu, a swipe to the right Done, to the left
/// Delete; carried, it takes another's place (the pool follows that order), over the list's right part it becomes the
/// subtask of the one above. Under the list, apart from it, one grey field to add the next. Show one at a time
/// (`TaskSteps`), under the subtasks once there is one: the pool shows only the next action, under this task's name; the
/// other subtasks are marked Later here.
struct SubtasksSection: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.actions) private var registry
    @Environment(\.openURL) private var openURL
    let editor: TaskEditor
    var header: LocalizedStringKey = "taskPage.subtasks"
    @State private var newName = ""
    @State private var height: CGFloat = 0
    @State private var pendingAction: PendingAction?

    var body: some View {
        if let draft = editor.draft {
            PlateSection(header: header, info: "info.taskPage.subtasks") { draftRows(draft) }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: Text(header), info: "info.taskPage.subtasks")
                let rows = tree
                if !rows.isEmpty {
                    ReorderableList(sections: Binding(get: { [ListSection(id: "subtasks", title: "", items: rows)] }, set: { moved($0, was: rows) }),
                                    look: "lists", actions: { engine.menu(.context(of: $0.task), for: $0) },
                                    traits: traits, swipes: { engine.swipes(.listTask, for: $0) }, onNest: nested,
                                    features: [.carry, .menu, .swipes, .nesting, .treeLines, .haptics, .dim, .scrollIndicator, .wrapTitles],
                                    onTap: { router.open(.task($0.id)) }, onHeight: { height = $0 }) { row($0) }
                        .frame(height: height)
                        .padding(.horizontal, -ListTheme.app.rows.sideInset)
                }
                Plate {
                    SubtaskField(text: $newName) {
                        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                        newName = ""
                        guard !name.isEmpty else { return }
                        Task { await model.addSubtask(name, to: editor.task.name) }
                    }
                    // Under the subtasks, once there is one.
                    if !editor.task.isHabit, editor.hasSubtasks(in: model) { oneAtATime }
                }
            }
            .actionConfirmation($pendingAction) { handler.run($0) }
        }
    }

    /// The subtasks and theirs, each under its parent, one level deeper.
    private var tree: [DayItem] {
        var rows: [DayItem] = []
        func add(under parent: String, depth: Int) {
            for subtask in model.subtasks(of: parent) where !rows.contains(where: { $0.id == subtask.name }) {
                var item = DayItem(listed: subtask)
                item.depth = depth
                rows.append(item)
                add(under: subtask.name, depth: depth + 1)
            }
        }
        add(under: editor.task.name, depth: 0)
        return rows
    }

    /// A done one in grey; a step waiting for an earlier one says Later.
    private func row(_ item: DayItem) -> ListRowContent {
        let isDone = item.task.isDone(on: model.context().today)
        let isLater = model.waitingSteps.contains(item.id)
        let started = item.task.isStarted && !isDone
        return ListRowContent(title: item.task.name,
                              chips: isLater ? [ListChip(kind: "later", content: .text(L10n.string("taskPage.steps.later")),
                                                         color: ThemeColor(tokens.uiColor(.secondaryText)))] : [],
                              icon: started ? .app(icons[.started]) : nil,
                              iconColor: ThemeColor(tokens.uiColor(.started)), iconGap: ListTheme.taskIconGap(started: started),
                              titleColor: isDone || isLater ? ThemeColor(tokens.uiColor(.secondaryText)) : nil)
    }

    private var traits: ListTraits<DayItem> {
        var traits = ListTraits<DayItem>()
        traits.depth = \.depth
        traits.canNest = { [model] child, parent in model.canNest(child.id, order: [parent.id, child.id]) }
        return traits
    }

    /// A subtask carried to another's place among the same parent's subtasks takes that place.
    private func moved(_ sections: [ListSection<DayItem>], was old: [DayItem]) {
        let before = old.map(\.id), after = sections.flatMap(\.items).map(\.id)
        guard let first = before.indices.first(where: { after.indices.contains($0) && before[$0] != after[$0] }) else { return }
        let candidate = after[first]
        let name = before.filter { $0 != candidate } == after.filter { $0 != candidate } ? candidate : before[first]
        guard let at = after.firstIndex(of: name), before.indices.contains(at) else { return }
        let target = before[at]
        let parent = old.first { $0.id == name }.flatMap { $0.task.projects.first } ?? editor.task.name
        model.moveSubtask(name, onto: target, of: parent)
    }

    /// Carried over the right part: under the one above; out from under its parent: a subtask of this task again.
    private func nested(_ name: String, _ nest: ListNest<String>) {
        Task { await model.nest(name, under: nest.parent ?? editor.task.name, index: nest.index) }
    }

    /// Show one at a time: the pool shows only the next action, under this task's name (`TaskSteps`); set when the task
    /// is made too.
    private var oneAtATime: some View {
        PlateRow(icon: .steps, title: "taskPage.steps", info: "info.taskPage.steps") {
            SwitchToggle("taskPage.steps", isOn: Binding(get: { editor.task.stepsOneByOne }, set: { editor.apply([.stepsOneByOne($0)]) }))
                .labelsHidden()
                .accessibilityIdentifier("taskPage.steps")
        }
    }

    private var engine: EngineActions {
        EngineActions(model: model, tokens: tokens, registry: registry, icons: icons) { handler.handle($0, taskName: $1) }
    }

    private var handler: TaskActionHandler {
        TaskActionHandler(model: model, router: router, openURL: openURL) { pendingAction = $0 }
    }

    /// A draft keeps its subtasks until the task is created; a filled field brings the next one.
    @ViewBuilder private func draftRows(_ draft: Binding<NoteDraft>) -> some View {
        let names = draft.wrappedValue.subtasks
        ForEach(Array((names + [""]).enumerated()), id: \.offset) { index, _ in
            SubtaskField(text: Binding(
                get: { index < draft.wrappedValue.subtasks.count ? draft.wrappedValue.subtasks[index] : "" },
                set: { value in
                    if index < draft.wrappedValue.subtasks.count {
                        draft.wrappedValue.subtasks[index] = value
                    } else if !value.isEmpty {
                        draft.wrappedValue.subtasks.append(value)
                    }
                }
            )) {}
        }
    }
}

/// The field for the next subtask's name; Return adds it.
private struct SubtaskField: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Binding var text: String
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: tokens.space(.iconTextGap)) {
            Image(systemName: icons[.addSubtask])
                .foregroundStyle(tokens.color(.tertiaryText))
                .frame(width: tokens.size(.iconColumn))
            TextField("taskPage.subtask.placeholder", text: $text)
                .foregroundStyle(tokens.color(.secondaryText))
                .submitLabel(.done)
                .onSubmit(onSubmit)
                .accessibilityIdentifier("taskPage.subtask")
        }
    }
}
