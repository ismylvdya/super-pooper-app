import SwiftUI

/// The arrows around the shown day's name ("Today", "26 Oct"; lying sideways "Mon", "Tod"); on another day, tapping the
/// name goes back to today. The name's frame is as wide as the widest name, so the arrows stay put; it shrinks if
/// the room is short. Sideways it is a column in physical order whose arrows point the same physical way as upright.
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
        let layout = bottom == nil ? AnyLayout(HStackLayout(spacing: tokens.space(.chipGap))) : AnyLayout(VStackLayout(spacing: tokens.space(.chipGap)))
        layout {
            ForEach(PhysicalBottom.physicalOrder([Part.previous, .name, .next], bottom: bottom), id: \.self) { part in
                switch part {
                case .previous: arrow(.previousDay, step: -1, label: "today.previousDay", id: "today.previousDay")
                case .name: name(title, names: names)
                case .next: arrow(.nextDay, step: 1, label: "today.nextDay", id: "today.nextDay")
                }
            }
        }
        .tint(tokens.color(.accent))
    }

    private func arrow(_ icon: Icon, step: Int, label: LocalizedStringKey, id: String) -> some View {
        Button { onStep(step) } label: {
            // Sideways (‹ ›) in every orientation, also when the arrows stand above and below the name.
            Image(systemName: icons[icon])
        }
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(id)
    }

    private func name(_ title: String, names: [String]) -> some View {
        Button(action: onToday) {
            ZStack {
                ForEach(names, id: \.self) { Text(verbatim: $0).hidden() }
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
