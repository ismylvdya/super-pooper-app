import SwiftUI

/// The order of the morning, day and evening routines: drag habits within a routine; the pool follows it.
/// Habits join a routine on their page (habit page → Routine).
struct RoutinesScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @State private var frames = ListGroupFrames()

    var body: some View {
        List {
            section(.morning, title: "routines.morning")
            section(.day, title: "routines.day")
            section(.evening, title: "routines.evening")
        }
        .listGroupStyle()
        .listGroupBacking(frames)
        .appList()
        .navigationTitle(Text("routines.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func section(_ part: HabitTimeOfDay, title: LocalizedStringKey) -> some View {
        let keyPath = AppSettings.Habits.routine(part)
        let members = HabitRoutines.members(part, of: model.habits, order: model.settings.habits[keyPath: keyPath])
        ListGroupHeader(title: Text(title))
        if members.isEmpty {
            Text("routines.empty").secondaryText(.hint)
                .listGroupRow(group: part.rawValue, id: "empty", isFirst: true, isLast: true, frames: frames)
        }
        ForEach(Array(members.enumerated()), id: \.element.name) { index, habit in
            NavigationLink(value: Route.task(habit.name)) {
                Text(habit.name).foregroundStyle(tokens.habitNameColor(habit))
            }
            .listGroupRow(group: part.rawValue, id: habit.name, isFirst: index == 0, isLast: index == members.count - 1,
                          frames: frames)
        }
        .onMove { source, destination in
            var names = members.map(\.name)
            names.move(fromOffsets: source, toOffset: destination)
            Haptics.play(.reorder)
            model.updateSettings { $0.habits[keyPath: keyPath] = names }
        }
        ListGroupFooter(text: Text("routines.hint"))
    }
}
