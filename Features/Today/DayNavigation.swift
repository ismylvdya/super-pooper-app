import CoreText
import SwiftUI
import UIKit

/// The arrows around the shown day's name ("Today", "Yesterday", "26 Oct · Wed"; lying sideways "Mon", "Tod"); on another day, tapping the
/// name goes back to today. The name's frame is as wide as the widest of them, so the
/// arrows stay put and stand `spacing.dayArrowGap` from it; it shrinks if the room is short. Sideways it is a column in physical order; the name stands turned, the arrows point left and right along the screen.
/// An arrow takes taps far beyond its glyph while everything stays where it was: the whole height of the bar
/// (`size.dayArrowTarget`), the room the bar's button style used to leave around the glyph and the gap to the name.
struct DayNavigation: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.physicalBottom) private var bottom
    let dayOffset: Int
    let onStep: (Int) -> Void
    let onToday: () -> Void

    private enum Part { case previous, name, next }

    var body: some View {
        let today = model.context().today
        let style: DayName.Style = .date
        let title = DayName.title(today.adding(days: dayOffset), offset: dayOffset, style: style, calendar: model.calendar)
        let names = DayName.frameNames(style, around: today, calendar: model.calendar)
        let layout = bottom == nil ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
        let order = PhysicalBottom.physicalOrder([Part.previous, .name, .next], bottom: bottom)
        let nameIndex = order.firstIndex(of: .name) ?? 0
        layout {
            ForEach(Array(order.enumerated()), id: \.element) { index, part in
                let towardName = edgeTowardName(beforeName: index < nameIndex)
                switch part {
                case .previous: arrow(.previousDay, step: -1, label: "today.previousDay", id: "today.previousDay", towardName: towardName)
                    .zIndex(1)
                case .name: name(title, names: names)
                case .next: arrow(.nextDay, step: 1, label: "today.nextDay", id: "today.nextDay", towardName: towardName)
                    .zIndex(1)
                }
            }
        }
        .tint(tokens.color(.accentToolbar))
    }

    /// The side of an arrow that faces the name: upright beside it, sideways above or below it.
    private func edgeTowardName(beforeName: Bool) -> Edge {
        switch (bottom == nil, beforeName) {
        case (true, true): .trailing
        case (true, false): .leading
        case (false, true): .bottom
        case (false, false): .top
        }
    }

    private func arrow(_ icon: Icon, step: Int, label: LocalizedStringKey, id: String, towardName edge: Edge) -> some View {
        let upright = bottom == nil
        return Button { onStep(step) } label: {
            // Lying sideways only the name is turned: an arrow still points along the screen, to the left or the right.
            Image(systemName: icons[icon])
                .padding(Edge.Set(edge.opposite), upright ? tokens.bar(.barButtonPadding) : 0)
                .padding(Edge.Set(edge), upright ? tokens.space(.dayArrowGap) : tokens.space(.chipGap))
                // Sideways as wide as the bar buttons of the column, and as long as the bar is high upright.
                .frame(width: upright ? nil : tokens.bar(.barButton), height: tokens.size(.dayArrowTarget), alignment: Alignment(edge))
                .contentShape(Rectangle())
        }
        // The bar's own button style pads the glyph with room that takes no taps; the plain style leaves the padding to
        // the label above, so all of it takes taps (the glyph keeps the bar's font and the tint's color).
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(id)
    }

    /// Upright the name may also take half the arrows' gap (still clear of their glyphs): its frame is that much wider on
    /// each side while the arrows stay where the widest name puts them, so a date shrinks less.
    private func name(_ title: String, names: [String]) -> some View {
        let overlap = bottom == nil ? tokens.space(.dayArrowGap) / 2 : 0
        return Button(action: onToday) {
            ZStack {
                if let widest = widest(of: names) { Text(verbatim: widest).hidden().padding(.horizontal, overlap) }
                Text(verbatim: title).titleSwap(title)
            }
            .font(tokens.font(.navTitle))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(bottom == nil ? tokens.size(.navTitleMin) / tokens.uiFont(.navTitle).pointSize : 1)
            // Sideways the three letters keep their size and may stand out of the narrow button column.
            .fixedSize(horizontal: bottom != nil, vertical: false)
            // The whole frame takes the tap, as tall as the arrows beside it.
            .frame(height: bottom == nil ? tokens.size(.dayArrowTarget) : nil)
            .quarterTurned(bottom)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, -overlap)
        // The bar's button style keeps its label at its full width; the plain one lets the name shrink into the bar's room.
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .accessibilityIdentifier("today.day")
    }
}

extension DayNavigation {
    /// The widest name in the bar's font with its digits as wide as each other (`.monospacedDigit()`), which the frame
    /// holds room for.
    private func widest(of names: [String]) -> String? {
        let base = tokens.uiFont(.navTitle)
        let digits: [UIFontDescriptor.FeatureKey: Int] = [.type: kNumberSpacingType, .selector: kMonospacedNumbersSelector]
        let font = UIFont(descriptor: base.fontDescriptor.addingAttributes([.featureSettings: [digits]]), size: base.pointSize)
        return DayName.widest(names) { NSAttributedString(string: $0, attributes: [.font: font]).size().width }
    }
}

private extension Edge {
    var opposite: Edge {
        switch self {
        case .top: .bottom
        case .bottom: .top
        case .leading: .trailing
        case .trailing: .leading
        }
    }
}

private extension Alignment {
    /// Against that edge, centered along it.
    init(_ edge: Edge) {
        switch edge {
        case .top: self = .top
        case .bottom: self = .bottom
        case .leading: self = .leading
        case .trailing: self = .trailing
        }
    }
}
