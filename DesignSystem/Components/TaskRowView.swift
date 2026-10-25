import SwiftUI

/// One task or habit row: title, property chips and what blocks it. Tasks are marked from the long-press menu,
/// so there is no checkbox; a marked row is grey and ends with its mark.
/// The same view is used in the pool, on the timeline and in widgets.
struct TaskRowView: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.titleReserve) private var reserve
    @Environment(\.icons) private var icons
    @Environment(\.rules) private var rules
    let item: DayItem
    let today: LocalDate
    var titleFont: Font?
    /// Chips and the "After: …" line; widgets hide them to stay compact.
    var showsDetails = true
    /// Narrow columns: one title line and one chip line that dissolves on the right.
    var isCompact = false
    /// Title lines; nil = compact rows get one line, others wrap freely.
    var titleLineLimit: Int?
    /// Line height of `titleFont` (nil = the task title token), for fading the last line.
    var titleLineHeight: CGFloat?
    var onOpen: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: tokens.space(.iconTextGap)) {
            VStack(alignment: .leading, spacing: tokens.space(.chipGap)) {
                title
                if showsDetails, !chips.isEmpty {
                    if isCompact {
                        // An overlay never widens the row: chips that don't fit dissolve on the right.
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: tokens.uiFont(.chip).lineHeight + tokens.space(.chipVertical) * 2)
                            .overlay(alignment: .leading) {
                                HStack(spacing: tokens.space(.chipGap)) { chipViews }.fixedSize()
                            }
                            .clipped()
                            .mask(TrailingFadeMask(width: tokens.size(.fadeHeight)))
                    } else {
                        ChipFlow(spacing: tokens.space(.chipGap)) { chipViews }
                    }
                }
                if showsDetails, !isCompact, item.isBlocked {
                    Label(L10n.format("row.after", blockerNames), systemImage: icons[.blocked])
                        .font(tokens.font(.caption))
                        .foregroundStyle(tokens.color(.secondaryText))
                }
            }
            Spacer(minLength: 0)
            if item.isDone { MarkGlyph(state: item.state, color: tokens.color(.past), size: tokens.size(.doneMark)) }
        }
        .opacity(item.isBlocked ? tokens.opacity(.blocked) : 1)
        .contentShape(Rectangle())
        // Anywhere on the row opens the task (chips included).
        .onTapGesture { onOpen?() }
    }

    private var chipViews: some View {
        ForEach(chips) { chip in Chip(icon: chip.icon, text: chip.text, tint: chip.tint) }
    }

    /// Limited titles fade out instead of ending with "…".
    @ViewBuilder private var titleText: some View {
        let font = titleFont ?? tokens.font(.taskTitle)
        if let lines = titleLineLimit ?? (isCompact ? 1 : nil) {
            FadingText(text: item.task.name, font: font, lineHeight: titleLineHeight ?? tokens.uiFont(.taskTitle).lineHeight,
                       lines: lines, reserve: reserve)
        } else {
            Text(item.task.name).font(font).multilineTextAlignment(.leading).padding(.trailing, reserve)
        }
    }

    @ViewBuilder private var title: some View {
        let text = titleText
            .foregroundStyle(item.isDone ? tokens.color(.secondaryText) : tokens.color(.primaryText))
        if let onOpen {
            Button(action: onOpen) { text }
                .buttonStyle(.plain)
                .accessibilityIdentifier("title:\(item.task.name)")
        } else {
            text
        }
    }

    private var blockerNames: String {
        L10n.list(item.blockers.map {
            switch $0 {
            case .task(let name): name
            case .event(let title, _): title
            }
        })
    }

    private var chips: [RowChip] {
        RowChip.chips(for: item, today: today, rules: rules, tokens: tokens)
    }
}

/// The property chips shown under a task title.
struct RowChip: Identifiable {
    let id: String
    let icon: Icon?
    let text: String?
    let tint: Color?

    static func chips(for item: DayItem, today: LocalDate, rules: RulesConfig, tokens: DesignTokens) -> [RowChip] {
        let task = item.task
        var result: [RowChip] = []
        if !item.problems.isEmpty { result.append(RowChip(id: "problem", icon: .problem, text: nil, tint: tokens.color(.problem))) }
        if task.isHighPriority { result.append(RowChip(id: "high", icon: .high, text: nil, tint: tokens.color(.high))) }
        if task.isHabit { result.append(RowChip(id: "habit", icon: .habit, text: nil, tint: tokens.color(.habit))) }
        if task.needEnergy { result.append(RowChip(id: "energy", icon: .energy, text: nil, tint: tokens.color(.energy))) }
        if task.pleasant == true { result.append(RowChip(id: "pleasant", icon: .pleasant, text: nil, tint: tokens.color(.heart))) }
        return result
    }
}

enum EstimateText {
    /// Labels come from `rules.json` (`2 min`, `15 min`, `1 h`, `dohuya`); empty = the default estimate.
    static func label(_ minutes: Int?, rules: RulesConfig) -> String {
        let value = (minutes ?? 0) > 0 ? minutes ?? 0 : rules.day.defaultEstimateMinutes
        if let option = rules.timeEstimates.first(where: { $0.minutes == value }) { return L10n.string(option.label) }
        return L10n.format("estimate.minutes", value)
    }
}

enum DueText {
    static func format(_ due: TaskDue, today: LocalDate, calendar: Calendar) -> String {
        let distance = today.days(until: due.day)
        let dayText: String
        switch distance {
        case 0: dayText = L10n.string("due.today")
        case 1: dayText = L10n.string("due.tomorrow")
        case -1: dayText = L10n.string("due.yesterday")
        case 2...6: dayText = calendar.shortWeekdaySymbols[due.day.weekday.rawValue % 7]
        default: dayText = due.day.startDate(in: calendar).formatted(.dateTime.month(.abbreviated).day())
        }
        guard let time = due.time else { return dayText }
        return distance == 0 ? time.string : L10n.format("due.dayAndTime", dayText, time.string)
    }
}

/// Opaque on the left, transparent over the last `width` points: content dissolves at the edge.
struct TrailingFadeMask: View {
    let width: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: width)
        }
    }
}

extension View {
    /// The plate a task row sits on (pool, widgets); a done row fades with its plate to the "past" opacity.
    func taskPlate(isDone: Bool = false) -> some View {
        modifier(TaskPlate(isDone: isDone))
    }
}

private struct TaskPlate: ViewModifier {
    @Environment(\.tokens) private var tokens
    let isDone: Bool

    func body(content: Content) -> some View {
        content
            .padding(.vertical, tokens.space(.rowVertical) / 2)
            .padding(.horizontal, tokens.space(.plateInner) / 2)
            .background(tokens.color(.plateBackground), in: RoundedRectangle(cornerRadius: tokens.radius(.poolRow), style: .continuous))
            .opacity(isDone ? tokens.opacity(.past) : 1)
    }
}
