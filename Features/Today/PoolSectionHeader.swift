import SwiftUI

/// A pool section's header: the app's section title, held and moved to drag the whole section within the pool.
struct PoolSectionHeader: View {
    @Environment(\.tokens) private var tokens
    let section: PoolSectionContent
    let isFirst: Bool
    let drag: TaskDragState?

    var body: some View {
        header
            .padding(.top, isFirst ? 0 : tokens.space(.poolSectionGap))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .modifier(SectionDragSource(id: section.id, drag: drag) { header })
            .accessibilityIdentifier("pool.section.\(section.id)")
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
