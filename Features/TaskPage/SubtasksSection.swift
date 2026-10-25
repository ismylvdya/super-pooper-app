import SwiftUI

/// Subtasks, the TaskNotes way: each is a task note of its own that lists this one in `projects`.
/// Under the existing ones there is always one empty field to add the next.
struct SubtasksSection: View {
    @Environment(AppModel.self) private var model
    let editor: TaskEditor
    @State private var newName = ""

    var body: some View {
        PlateSection(header: "taskPage.subtasks", info: "info.taskPage.subtasks") {
            if let draft = editor.draft {
                draftRows(draft)
            } else {
                // A link, not the router: in the morning review the page is in the sheet's own stack.
                ForEach(model.subtasks(of: editor.task.name), id: \.name) { subtask in
                    NavigationLink(value: Route.task(subtask.name)) {
                        SubtaskLabel(name: subtask.name, isDone: subtask.status.isCompleted)
                    }
                    .buttonStyle(.plain)
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
        PlateRow(icon: .subtask, title: Text(verbatim: name)) {
            Image(systemName: icons[.chevron]).foregroundStyle(tokens.color(.tertiaryText))
        }
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
