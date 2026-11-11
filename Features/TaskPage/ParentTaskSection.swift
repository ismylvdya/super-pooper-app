import SwiftUI

/// The task this one stands under, as a row that opens it; no section for a task under none.
struct ParentTaskSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let editor: TaskEditor

    var body: some View {
        if !editor.isDraft, let parent = editor.task.projects.first.flatMap(model.task(named:)) {
            PlateSection(header: "taskPage.parent", info: "info.taskPage.parent") {
                // A link, not the router: in the morning review the page is in the sheet's own stack.
                NavigationLink(value: Route.task(parent.name)) {
                    HStack(spacing: tokens.space(.iconTextGap)) {
                        Image(systemName: icons[.parentTask])
                            .foregroundStyle(tokens.color(.accent))
                            .frame(width: tokens.size(.iconColumn))
                        FadingText(text: parent.name, font: tokens.font(.rowTitle), lineHeight: tokens.uiFont(.rowTitle).lineHeight)
                            .foregroundStyle(tokens.color(.primaryText))
                        DisclosureAccessory()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("taskPage.parent")
            }
        }
    }
}
