import ListEngineChumbulev
import SwiftUI

/// The order of the morning and evening routines: drag habits within a routine; the pool follows it. Habits join a
/// routine on their page (habit page → Routine); a tap opens it. A list of the list engine, rows carried only, each
/// within its routine.
struct RoutinesScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens

    private static let parts: [HabitTimeOfDay] = [.morning, .evening]

    var body: some View {
        ReorderableList(sections: Binding(get: { sections }, set: save), look: "lists",
                        features: ListFeatures.orderOnly, onTap: { router.open(.task($0.id)) },
                        footer: AnyView(PlateHint(text: Text("routines.hint"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, ListTheme.app.rows.sideInset))) { row in
            ListRowContent(title: row.id, titleColor: model.habits.first { $0.name == row.id }.map { ThemeColor(tokens.habitNameColor($0)) })
        }
        .ignoresSafeArea()
        .navigationTitle(Text("routines.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sections: [ListSection<OrderedRow>] {
        Self.parts.map { part in
            let members = HabitRoutines.members(part, of: model.habits, order: model.settings.habits[keyPath: AppSettings.Habits.routine(part)])
            return ListSection(id: part.rawValue, title: L10n.string("routines." + part.rawValue), items: members.map { OrderedRow(id: $0.name) })
        }
    }

    private func save(_ sections: [ListSection<OrderedRow>]) {
        for section in sections {
            guard let part = HabitTimeOfDay(rawValue: section.id) else { continue }
            model.updateSettings { $0.habits[keyPath: AppSettings.Habits.routine(part)] = section.items.map(\.id) }
        }
    }
}
