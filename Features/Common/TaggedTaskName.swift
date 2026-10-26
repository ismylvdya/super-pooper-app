import SwiftUI

/// A task's name after the emoji of the task tag (🔫 for `🔫делишка`), as tasks stand in search and lists.
struct TaggedTaskName: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    let name: String

    var body: some View {
        HStack(spacing: tokens.space(.iconTextGap)) {
            if let emoji = TagEmoji.leading(of: model.settings.vault.taskTag) {
                Text(verbatim: emoji).font(tokens.font(.caption))
            }
            Text(verbatim: name).foregroundStyle(tokens.color(.primaryText))
        }
    }
}
