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
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    // As a habit of a routine in the pool: the row covers its piece of the plate (over the plate's
                    // inner margins and half the gaps) with the plate's color, and that whole piece lifts as a
                    // rounded plate.
                    .padding(.horizontal, tokens.space(.plateInner))
                    .padding(.vertical, tokens.space(.plateRowGap) / 2)
                    .background(tokens.color(.plateBackground))
                    .contentShape(.dragPreview, PlateShape(cornerRadius: tokens.rowPlateRadius))
                    .onDrag {
                        dragged = subtask.name
                        return NSItemProvider(object: subtask.name as NSString)
                    }
                    .padding(.horizontal, -tokens.space(.plateInner))
                    .padding(.vertical, -tokens.space(.plateRowGap) / 2)
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

    /// A long name fades out before the chevron instead of pushing it to a line of its own.
    var body: some View {
        HStack(spacing: tokens.space(.iconTextGap)) {
            Image(icon: .subtask, icons: icons)
                .renderingMode(.template)
                .foregroundStyle(tokens.color(.accent))
                .frame(width: tokens.size(.iconColumn))
            FadingText(text: name, font: tokens.font(.rowTitle), lineHeight: tokens.uiFont(.rowTitle).lineHeight)
                .strikethrough(isDone)
            DisclosureAccessory()
        }
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
