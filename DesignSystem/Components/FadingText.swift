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

    var body: some View {
        let fade = tokens.size(.titleFade)
        Group {
            if lines <= 1 {
                Text(text)
                    .font(font)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        .accessibilityLabel(Text(text))
    }
}

/// The mark of a timeline block that will send a notification: a plain bell in the text color, faded.
/// Size and opacity come from the settings.
struct AlertBell: View {
    @Environment(\.icons) private var icons
    @Environment(\.timelineBell) private var bell

    var body: some View {
        Image(systemName: icons[.bell])
            .resizable()
            .scaledToFit()
            .frame(width: bell.size, height: bell.size)
            .foregroundStyle(Color.primary.opacity(bell.opacity))
            .accessibilityLabel(Text("timeline.alert"))
    }
}

/// Bell size and opacity from the settings, and the room titles keep free for the corner icons.
struct TimelineBellStyle: Equatable {
    var size: CGFloat = 11
    var opacity: Double = 0.45
}

private struct TimelineBellKey: EnvironmentKey {
    static let defaultValue = TimelineBellStyle()
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
