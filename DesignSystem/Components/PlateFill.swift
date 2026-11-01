import SwiftUI
import WidgetKit

extension View {
    /// The content on a plate: `fill` (the plates' color unless given) in the plate's shape. `clipsContent` cuts what
    /// reaches past the plate (a scroll, a past event's stripe, the pages of a paged preview). In a widget rendered in
    /// one tint the plates' color is see-through (`WidgetRendering`); a given fill is already a tint of its own.
    func plate(_ corners: PlateCorners, fill: Color? = nil, clipsContent: Bool = false) -> some View {
        modifier(PlateFill(corners: corners, fill: fill, clipsContent: clipsContent))
    }

    /// A long press (`.contextMenuPreview`) or a drag (`.dragPreview`) lifts exactly the plate: its shape, not the
    /// view's rectangle.
    func plateLift(_ corners: PlateCorners, for kinds: ContentShapeKinds = [.contextMenuPreview, .dragPreview]) -> some View {
        modifier(PlateLift(corners: corners, kinds: kinds))
    }
}

private struct PlateFill: ViewModifier {
    @Environment(\.tokens) private var tokens
    @Environment(\.widgetRenderingMode) private var renderingMode
    let corners: PlateCorners
    let fill: Color?
    let clipsContent: Bool

    func body(content: Content) -> some View {
        let shape = tokens.plateShape(corners)
        if clipsContent {
            content.background(fill ?? plateColor, in: shape).clipShape(shape)
        } else {
            content.background(fill ?? plateColor, in: shape)
        }
    }

    private var plateColor: Color {
        let opacity = WidgetRendering.plateOpacity(corners, in: renderingMode, tokens: tokens)
        let color = tokens.color(.plateBackground)
        return opacity < 1 ? color.opacity(opacity) : color
    }
}

private struct PlateLift: ViewModifier {
    @Environment(\.tokens) private var tokens
    let corners: PlateCorners
    let kinds: ContentShapeKinds

    func body(content: Content) -> some View {
        content.contentShape(kinds, tokens.plateShape(corners))
    }
}
