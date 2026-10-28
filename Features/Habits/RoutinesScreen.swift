import SwiftUI

/// The order of the morning, day and evening routines: drag habits within a routine; the pool follows it.
/// Habits join a routine on their page (habit page → Routine).
struct RoutinesScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @State private var frames = ListGroupFrames()

    var body: some View {
        List {
            section(.morning, title: "routines.morning", keyPath: \.morningRoutine)
            section(.day, title: "routines.day", keyPath: \.dayRoutine)
            section(.evening, title: "routines.evening", keyPath: \.eveningRoutine)
        }
        .listGroupStyle()
        .listGroupBacking(frames)
        .appList()
        .navigationTitle(Text("routines.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func section(_ part: HabitTimeOfDay, title: LocalizedStringKey, keyPath: WritableKeyPath<AppSettings.Habits, [String]>) -> some View {
        let members = HabitRoutines.members(part, of: model.habits, order: model.settings.habits[keyPath: keyPath])
        ListGroupHeader(title: Text(title))
        if members.isEmpty {
            Text("routines.empty").font(tokens.font(.hint)).foregroundStyle(tokens.color(.secondaryText))
                .padding(.horizontal, tokens.space(.plateInner))
                .padding(.vertical, tokens.space(.listRowVertical))
                .listGroupRow(group: part.rawValue, id: "empty", isFirst: true, isLast: true, frames: frames,
                              separatorInset: tokens.space(.plateInner))
        }
        ForEach(Array(members.enumerated()), id: \.element.name) { index, habit in
            NavigationLink(value: Route.task(habit.name)) {
                Text(habit.name).foregroundStyle(tokens.habitNameColor(habit))
            }
            .padding(.horizontal, tokens.space(.plateInner))
            .padding(.vertical, tokens.space(.listRowVertical))
            .listGroupRow(group: part.rawValue, id: habit.name, isFirst: index == 0, isLast: index == members.count - 1,
                          frames: frames, separatorInset: tokens.space(.plateInner))
            // Rebuilt when it becomes or stops being first or last, so the corners follow a new order.
            .id("\(habit.name)|\(index == 0)|\(index == members.count - 1)")
        }
        .onMove { source, destination in
            var names = members.map(\.name)
            names.move(fromOffsets: source, toOffset: destination)
            Haptics.play(.medium)
            model.updateSettings { $0.habits[keyPath: keyPath] = names }
        }
        ListGroupFooter(text: Text("routines.hint"))
    }
}
