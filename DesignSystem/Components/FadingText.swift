import SwiftUI

/// A title that never shows "…": what does not fit dissolves at the right edge (and before `reserve`
/// points kept free, see `TitleFade`). With several lines, the text wraps and the last line fades.
struct FadingText: View {
    @Environment(\.tokens) private var tokens
    let text: String
    let font: Font
    /// Line height of `font`, for clipping several lines.
    let lineHeight: CGFloat
    var lines = 1
    var reserve: CGFloat = 0
    @State private var width: CGFloat = .infinity

    var body: some View {
        let fade = tokens.size(.titleFade)
        // A narrow column would break words letter by letter: one fading line there.
        let isNarrow = width < tokens.size(.wrapMinWidth)
        let lines = isNarrow ? 1 : self.lines
        Group {
            if lines <= 1 {
                // An overlay never widens the layout: the line keeps its natural width and is cut by the frame.
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: lineHeight)
                    .overlay(alignment: .leading) {
                        Text(text).font(font).lineLimit(1).fixedSize()
                    }
            } else {
                Text(text)
                    .font(font)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(maxHeight: lineHeight * CGFloat(lines), alignment: .top)
            }
        }
        .clipped()
        .mask {
            VStack(spacing: 0) {
                if lines > 1 { Color.black.frame(height: lineHeight * CGFloat(lines - 1)) }
                HStack(spacing: 0) {
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: fade)
                }
            }
        }
        .padding(.trailing, reserve)
        // Measured outside the padding, so the shift above never feeds back into the width.
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .accessibilityLabel(Text(text))
    }
}

private struct TitleReserveKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// How far from a block's right edge its corner marks (the link mark, the bell) reach; 0 = none.
    var titleReserve: CGFloat {
        get { self[TitleReserveKey.self] }
        set { self[TitleReserveKey.self] = newValue }
    }

    /// The right inset of the plate a row sits on (set by the plate), for `TitleFade`.
    var plateTrailingInset: CGFloat {
        get { self[PlateTrailingInsetKey.self] }
        set { self[PlateTrailingInsetKey.self] = newValue }
    }
}

/// One rule for every fading title: it has faded out `fadeGap` points before what stands at its right — a chip, the
/// corner marks, or the plate's edge when there is nothing — whatever the layout, the widget or the text length.
enum TitleFade {
    /// Points a title keeps free at its right inside a plate whose own right inset is `plateInset`, with corner marks
    /// reaching `corner` points from the plate's edge (0 = none).
    static func trailing(corner: CGFloat, plateInset: CGFloat, gap: CGFloat) -> CGFloat {
        max(0, corner + gap - plateInset)
    }
}

private struct PlateTrailingInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}
