import SwiftUI

/// The name of the task a row belongs to, small and grey over the row's own name: a subtask shown without its parent,
/// the next action of a task shown one at a time. Every row that shows one uses this.
struct ParentCaption<Title: View>: View {
    @Environment(\.tokens) private var tokens
    let parent: String?
    @ViewBuilder let title: Title

    var body: some View {
        if let parent {
            VStack(alignment: .leading, spacing: tokens.space(.projectCaptionGap)) {
                Text(verbatim: parent)
                    .font(tokens.font(.projectCaption))
                    .foregroundStyle(tokens.color(.secondaryText))
                    .lineLimit(1)
                    .accessibilityIdentifier("parentCaption:\(parent)")
                title
            }
        } else {
            title
        }
    }
}
