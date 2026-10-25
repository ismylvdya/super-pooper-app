import SwiftUI

/// A title that never shows "…": what does not fit dissolves at the right edge (and before `reserve`
/// points kept free for icons in the corner). With several lines, the text wraps and the last line fades.
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
        // In a narrow column every letter counts: the line runs a few letters on under the corner icons
        // and into the plate's padding before it fades.
        .padding(.trailing, isNarrow ? reserve - tokens.size(.narrowFadeShift) : reserve)
        // Measured outside the padding, so the shift above never feeds back into the width.
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .accessibilityLabel(Text(text))
    }
}

/// The mark of a timeline block that will send a notification: a plain bell in the text color, faded.
/// Size and opacity come from the settings.
struct AlertBell: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.timelineBell) private var bell

    var body: some View {
        Image(systemName: icons[.bell])
            .resizable()
            .scaledToFit()
            .frame(width: bell.size, height: bell.size)
            .foregroundStyle(tokens.color(.primaryText).opacity(bell.opacity))
            .accessibilityLabel(Text("timeline.alert"))
    }
}

/// Bell size and opacity from the settings, and the room titles keep free for the corner icons.
struct TimelineBellStyle: Equatable {
    var size: CGFloat
    var opacity: Double
}

private struct TimelineBellKey: EnvironmentKey {
    static let defaultValue = BundledConfig.settings.timeline.bellStyle
}

private struct TitleReserveKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var timelineBell: TimelineBellStyle {
        get { self[TimelineBellKey.self] }
        set { self[TimelineBellKey.self] = newValue }
    }

    /// Points at the right of a block title kept free for the bell and the link mark.
    var titleReserve: CGFloat {
        get { self[TitleReserveKey.self] }
        set { self[TitleReserveKey.self] = newValue }
    }
}

extension AppSettings.Timeline {
    var bellStyle: TimelineBellStyle { TimelineBellStyle(size: bellSize, opacity: bellOpacity) }
}
