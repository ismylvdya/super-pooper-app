import SwiftUI

/// The widget title: one line that fades out; with "Wrap Title" a title that does not fit goes to two
/// lines a third smaller, by words or (with "Break Words") by letters with a hyphen.
struct HabitWidgetTitle: View {
    @Environment(\.tokens) private var tokens
    let text: String
    /// The size picked in the widget's settings; nil = the `widgetTitle` token's.
    let size: Double?
    var wrap = false
    var breakWords = false

    var body: some View {
        let type = TitleType(tokens: tokens, size: size ?? Double(tokens.uiFont(.widgetTitle).pointSize))
        let small = TitleType(tokens: tokens, size: type.size * Double(tokens.ratio(.widgetWrappedTitle)))
        let lines = tokens.count(.widgetTitleLines)
        if wrap {
            ViewThatFits(in: .horizontal) {
                Text(text).font(type.font).lineLimit(1).fixedSize()
                if breakWords {
                    GeometryReader { geometry in
                        let split = HyphenSplit.split(text, width: geometry.size.width, font: small.uiFont)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(split.first).font(small.font).lineLimit(1)
                            FadingText(text: split.rest, font: small.font, lineHeight: small.lineHeight, lines: lines - 1)
                        }
                    }
                    .frame(height: small.lineHeight * CGFloat(lines))
                } else {
                    FadingText(text: text, font: small.font, lineHeight: small.lineHeight, lines: lines)
                }
            }
        } else {
            FadingText(text: text, font: type.font, lineHeight: type.lineHeight)
        }
    }

    /// The title's font at one size, for SwiftUI and for UIKit (its line height, the hyphenation's measuring).
    private struct TitleType {
        let size: Double
        let font: Font
        let uiFont: UIFont

        init(tokens: DesignTokens, size: Double) {
            self.size = size
            font = tokens.font(.widgetTitle, size: size)
            uiFont = tokens.uiFont(.widgetTitle, size: size)
        }

        var lineHeight: CGFloat { uiFont.lineHeight }
    }
}
