import SwiftUI

/// The order of the morning and evening routines: drag habits within a routine; the pool follows it.
/// Habits join a routine by their part of the day (habit page → Part of the day).
struct RoutinesScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens

    var body: some View {
        List {
            section(.morning, title: "routines.morning", keyPath: \.morningRoutine)
            section(.evening, title: "routines.evening", keyPath: \.eveningRoutine)
        }
        .appList()
        .navigationTitle(Text("routines.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func section(_ part: HabitTimeOfDay, title: LocalizedStringKey, keyPath: WritableKeyPath<AppSettings.Habits, [String]>) -> some View {
        let members = HabitRoutines.members(part, of: model.habits, order: model.settings.habits[keyPath: keyPath])
        Section {
            if members.isEmpty {
                Text("routines.empty").font(tokens.font(.hint)).foregroundStyle(tokens.color(.secondaryText))
                    .listRowBackground(tokens.color(.plateBackground))
            }
            ForEach(members, id: \.name) { habit in
                NavigationLink(value: Route.task(habit.name)) {
                    Text(habit.name).foregroundStyle(tokens.habitColor(habit))
                }
                .listRowBackground(tokens.color(.plateBackground))
            }
            .onMove { source, destination in
                var names = members.map(\.name)
                names.move(fromOffsets: source, toOffset: destination)
                Haptics.play(.medium)
                model.updateSettings { $0.habits[keyPath: keyPath] = names }
            }
        } header: {
            Text(title)
        } footer: {
            Text("routines.hint")
        }
    }
}
