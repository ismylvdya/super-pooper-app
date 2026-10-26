import SwiftUI

/// Subtasks, the TaskNotes way: each is a task note of its own that lists this one in `projects`.
/// Under the existing ones there is always one empty field to add the next. A subtask picked up (long press)
/// and dropped on another one takes its place; the pool follows that order.
struct SubtasksSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    let editor: TaskEditor
    @State private var newName = ""
    @State private var dragged: String?
    @State private var target: String?
    /// The rows' width, for the lifted plate.
    @State private var rowWidth: CGFloat = 0

    var body: some View {
        PlateSection(header: "taskPage.subtasks", info: "info.taskPage.subtasks") {
            if let draft = editor.draft {
                draftRows(draft)
            } else {
                // A link, not the router: in the morning review the page is in the sheet's own stack.
                let subtasks = model.subtasks(of: editor.task.name)
                let names = subtasks.map(\.name)
                ForEach(subtasks, id: \.name) { subtask in
                    NavigationLink(value: Route.task(subtask.name)) {
                        SubtaskLabel(name: subtask.name, isDone: subtask.status.isCompleted)
                    }
                    .buttonStyle(.plain)
                    // Lifted as a rounded plate of its own, not as a bare rectangle of the row.
                    .contentShape(.dragPreview, RoundedRectangle(cornerRadius: tokens.radius(.poolRow), style: .continuous))
                    .onDrag({
                        dragged = subtask.name
                        return NSItemProvider(object: subtask.name as NSString)
                    }, preview: {
                        SubtaskLabel(name: subtask.name, isDone: subtask.status.isCompleted)
                            .padding(.vertical, tokens.space(.rowVertical) / 2)
                            .padding(.horizontal, tokens.space(.plateInner) / 2)
                            .frame(width: rowWidth)
                            .background(tokens.color(.plateBackground),
                                        in: RoundedRectangle(cornerRadius: tokens.radius(.poolRow), style: .continuous))
                    })
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
                    .onDrop(of: TaskDragState.types, isTargeted: targetBinding(subtask.name)) { _ in
                        drop(onto: subtask.name)
                    }
                    .overlay(alignment: dropEdge(onto: subtask.name, names: names)) {
                        if target == subtask.name, dragged != subtask.name {
                            Rectangle().fill(tokens.color(.accent)).frame(height: tokens.size(.subtaskDropLine))
                        }
                    }
                    .accessibilityIdentifier("subtask:\(subtask.name)")
                }
                SubtaskField(text: $newName) {
                    let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                    newName = ""
                    guard !name.isEmpty else { return }
                    Task { await model.addSubtask(name, to: editor.task.name) }
                }
            }
        }
    }

    private func targetBinding(_ name: String) -> Binding<Bool> {
        Binding(get: { target == name }, set: { isOver in
            if isOver { target = name } else if target == name { target = nil }
        })
    }

    private func drop(onto name: String) -> Bool {
        defer { dragged = nil; target = nil }
        guard let dragged else { return false }
        Haptics.play(.medium)
        model.moveSubtask(dragged, onto: name, of: editor.task.name)
        return true
    }

    /// The line shows where the dragged subtask goes: under a row below it, above a row above it.
    private func dropEdge(onto name: String, names: [String]) -> Alignment {
        guard let dragged, let from = names.firstIndex(of: dragged), let to = names.firstIndex(of: name) else { return .top }
        return from < to ? .bottom : .top
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

/// An existing subtask: its name, struck through when done.
private struct SubtaskLabel: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let name: String
    let isDone: Bool

    var body: some View {
        PlateRow(icon: .subtask, title: Text(verbatim: name)) { DisclosureAccessory() }
        .strikethrough(isDone)
        .contentShape(Rectangle())
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
                .submitLabel(.done)
                .onSubmit(onSubmit)
                .accessibilityIdentifier("taskPage.subtask")
        }
    }
}
