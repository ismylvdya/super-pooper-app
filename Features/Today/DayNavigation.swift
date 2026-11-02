import CoreText
import SwiftUI
import UIKit

/// The arrows around the shown day's name ("Today", "Yesterday", "26 Oct • Wed"; lying sideways "Mon", "Tod"); on another day, tapping the
/// name goes back to today. The name's frame is as wide as the widest name, so the arrows stay put; it shrinks if
/// the room is short. Sideways it is a column in physical order whose arrows point the same physical way as upright.
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
        let style: DayName.Style = bottom == nil ? .date : .weekday
        let title = DayName.title(today.adding(days: dayOffset), offset: dayOffset, style: style, calendar: model.calendar)
        let names = DayName.all(style, around: today, calendar: model.calendar)
        let layout = bottom == nil ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
        let order = PhysicalBottom.physicalOrder([Part.previous, .name, .next], bottom: bottom)
        let nameIndex = order.firstIndex(of: .name) ?? 0
        layout {
            ForEach(Array(order.enumerated()), id: \.element) { index, part in
                let towardName = edgeTowardName(beforeName: index < nameIndex)
                switch part {
                case .previous: arrow(.previousDay, step: -1, label: "today.previousDay", id: "today.previousDay", towardName: towardName)
                case .name: name(title, names: names)
                case .next: arrow(.nextDay, step: 1, label: "today.nextDay", id: "today.nextDay", towardName: towardName)
                }
            }
        }
        .tint(tokens.color(.accent))
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
            // Sideways (‹ ›) in every orientation, also when the arrows stand above and below the name.
            Image(systemName: icons[icon])
                .padding(.horizontal, upright ? tokens.bar(.barButtonPadding) : 0)
                .padding(Edge.Set(edge), tokens.space(.chipGap))
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

    private func name(_ title: String, names: [String]) -> some View {
        Button(action: onToday) {
            ZStack {
                if let widest = widest(of: names) { Text(verbatim: widest).hidden() }
                Text(verbatim: title)
            }
            .font(tokens.font(.navTitle))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(bottom == nil ? tokens.size(.navTitleMin) / tokens.uiFont(.navTitle).pointSize : 1)
            // Sideways the three letters keep their size and may stand out of the narrow button column.
            .fixedSize(horizontal: bottom != nil, vertical: false)
        }
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
