import SwiftUI
import WidgetKit

extension View {
    /// The content on a plate: `fill` (the plates' color unless given) in the plate's shape. `clipsContent` cuts what
    /// reaches past the plate (a scroll, a past event's stripe, the pages of a paged preview). In a widget rendered in
    /// one tint the plates' color is see-through (`WidgetRendering`); a given fill is already a tint of its own.
    /// `tint` lies over the fill (a high-priority task's soft red over its plate).
    /// `maxRadius` rounds it no more than that (a shared plate, no rounder than the rows on it).
    func plate(_ corners: PlateCorners, fill: Color? = nil, tint: Color? = nil, clipsContent: Bool = false,
               maxRadius: CGFloat = .infinity) -> some View {
        modifier(PlateFill(corners: corners, fill: fill, tint: tint, clipsContent: clipsContent, maxRadius: maxRadius))
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
    let tint: Color?
    let clipsContent: Bool
    let maxRadius: CGFloat
    @Environment(\.plateGradient) private var gradient

    func body(content: Content) -> some View {
        let shape = PlateShape(cornerRadius: min(tokens.plateRadius(corners), maxRadius))
        let color = fill ?? plateColor
        // The gradient belongs to this plate only, not to plates inside it.
        let surfaced = content.environment(\.plateSurface, color).environment(\.plateGradient, nil)
            .background(tint ?? .clear, in: shape)
            .background { if let gradient { gradient.clipShape(shape) } }
            .background(color, in: shape)
        if clipsContent {
            surfaced.clipShape(shape)
        } else {
            surfaced
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

private struct PlateGradientKey: EnvironmentKey {
    static let defaultValue: AnyView? = nil
}

extension EnvironmentValues {
    /// A fill the next plate out draws over its color and under its tint (a started task's `StartedFill`).
    var plateGradient: AnyView? {
        get { self[PlateGradientKey.self] }
        set { self[PlateGradientKey.self] = newValue }
    }
}

private struct PlateSurfaceKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

extension EnvironmentValues {
    /// The color of the plate a view lies on (nil: on no plate). An element with see-through parts (a habit day's rings)
    /// backs them with it, so lifted it never shows what lies under it.
    var plateSurface: Color? {
        get { self[PlateSurfaceKey.self] }
        set { self[PlateSurfaceKey.self] = newValue }
    }
}
