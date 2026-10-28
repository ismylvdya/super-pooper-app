import SwiftUI

/// A note's name as tasks and habits stand in search and lists: a task after the emoji of the task tag (🔫 for
/// `🔫делишка`), a habit after the habit symbol in its marks' color.
struct TaggedTaskName: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let name: String

    var body: some View {
        HStack(spacing: tokens.space(.iconTextGap)) {
            if let habit = model.task(named: name), habit.isHabit {
                Image(systemName: icons[.habit]).font(tokens.font(.caption)).foregroundStyle(tokens.habitMarkColor(habit))
            } else if let emoji = TagEmoji.leading(of: model.settings.vault.taskTag) {
                Text(verbatim: emoji).font(tokens.font(.caption))
            }
            Text(verbatim: name).foregroundStyle(tokens.color(.primaryText))
        }
    }
}
