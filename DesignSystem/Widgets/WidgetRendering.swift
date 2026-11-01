import WidgetKit

/// What a widget's rendering mode leaves of the app's colors. Full color shows them as they are. In the accented mode
/// (the tinted Home Screen, on iOS 26 also the clear one) and the vibrant one (the Lock Screen) the system keeps only how
/// opaque each view is and paints it in one of two tints: an opaque plate would come out as solid as the title on it.
enum WidgetRendering {
    /// How much of the plates' color a plate keeps: all of it in full color; otherwise `accentedPlate`, and nothing for a
    /// plate that lies on another one.
    static func plateOpacity(_ corners: PlateCorners, in mode: WidgetRenderingMode, tokens: DesignTokens) -> Double {
        guard mode != .fullColor else { return 1 }
        return corners.liesOnPlate ? 0 : tokens.opacity(.accentedPlate)
    }
}
