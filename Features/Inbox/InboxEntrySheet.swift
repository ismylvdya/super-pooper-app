import SwiftUI

/// "New in inbox" from the Home Screen: one field with the cursor in it; Return adds the reminder to the inbox
/// list of Reminders and closes the sheet.
struct InboxEntrySheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.tokens) private var tokens
    @State private var title = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            Plate {
                TextField("inbox.placeholder", text: $title, axis: .vertical)
                    .font(tokens.font(.rowTitle))
                    .submitLabel(.done)
                    .focused($isFocused)
                    .onChange(of: title) { _, value in
                        // Return in a vertical field inserts a newline: it means "add".
                        guard value.contains("\n") else { return }
                        title = value.replacingOccurrences(of: "\n", with: "")
                        add()
                    }
                    .accessibilityIdentifier("inbox.title")
            }
            .padding(.horizontal, tokens.space(.screenHorizontal))
            .frame(maxHeight: .infinity, alignment: .top)
            .background(tokens.color(.screenBackground))
            .navigationTitle(Text(verbatim: model.config.rules.inbox.listTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("inbox.add", action: add).disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .task { isFocused = true }
        }
        .presentationDetents([.medium])
    }

    private func add() {
        if model.addToInbox(title) { dismiss() }
    }
}
