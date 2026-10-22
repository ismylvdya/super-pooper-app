import SwiftUI

/// Search through the vault's tasks to link one.
struct TaskPickerScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.tokens) private var tokens
    let excluded: Set<String>
    let onPick: (String) -> Void
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(results, id: \.name) { task in
                Button {
                    onPick(task.name)
                    dismiss()
                } label: {
                    HStack {
                        Text(task.name).foregroundStyle(tokens.color(.primaryText))
                        Spacer()
                        Text(StatusText.title(task.status)).font(tokens.font(.hint)).foregroundStyle(tokens.color(.secondaryText))
                    }
                }
            }
            .overlay { if results.isEmpty { Text("picker.task.empty").foregroundStyle(tokens.color(.secondaryText)) } }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("picker.task.search"))
            .navigationTitle(Text("picker.task.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } } }
        }
    }

    private var results: [TaskNote] {
        model.tasks
            .filter { !excluded.contains($0.name) && $0.status != .archived }
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
