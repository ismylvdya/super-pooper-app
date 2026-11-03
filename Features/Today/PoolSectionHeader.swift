import SwiftUI

/// A pool section's header: the app's section title. A tap puts the cursor in it and the keyboard up, the title is edited
/// in place (that day only); held and moved, it drags the whole section within the pool. A section goes away by itself
/// when no task is left in it.
struct PoolSectionHeader: View {
    @Environment(\.tokens) private var tokens
    let section: PoolSectionContent
    let isFirst: Bool
    let drag: TaskDragState?
    var canRename = true
    let onRename: (String) -> Void
    @State private var isEditing = false
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isEditing { field } else { title }
        }
        .padding(.top, isFirst ? 0 : tokens.space(.poolSectionGap))
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityIdentifier("pool.section.\(section.id)")
    }

    private var title: some View {
        header
            .onTapGesture {
                guard canRename else { return }
                text = shownTitle
                isEditing = true
                isFocused = true
            }
            .modifier(SectionDragSource(id: section.id, drag: drag) { header })
    }

    private var field: some View {
        TextField("", text: $text)
            .font(tokens.font(.sectionHeader))
            .foregroundStyle(tokens.color(.sectionHeader))
            .focused($isFocused)
            .submitLabel(.done)
            .padding(.horizontal, tokens.space(.sectionHeaderInset))
            .padding(.bottom, tokens.space(.headerToPlate))
            .onSubmit(finish)
            .onChange(of: isFocused) { _, focused in if !focused { finish() } }
            .accessibilityIdentifier("pool.section.name")
    }

    private func finish() {
        guard isEditing else { return }
        isEditing = false
        if text != shownTitle { onRename(text) }
    }

    /// The title as the header shows it.
    private var shownTitle: String {
        section.isCustom ? section.title : L10n.string(section.title)
    }

    private var header: some View {
        SectionHeader(title: section.isCustom ? Text(verbatim: section.title) : Text(LocalizedStringKey(section.title)))
            .accessibilityAddTraits(.isHeader)
    }
}

/// Long press and move picks the section up by its header.
private struct SectionDragSource<Preview: View>: ViewModifier {
    let id: String
    let drag: TaskDragState?
    @ViewBuilder let preview: () -> Preview

    func body(content: Content) -> some View {
        if let drag {
            content.onDrag { drag.beginSection(id) } preview: { preview() }
        } else {
            content
        }
    }
}
