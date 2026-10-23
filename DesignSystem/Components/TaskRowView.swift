import AppIntents
import SwiftUI

/// One task or habit row: checkbox, title, property chips and what blocks it.
/// The same view is used in the pool, on the timeline and in widgets.
struct TaskRowView: View {
    @Environment(\.tokens) private var tokens
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
    var onToggle: (() -> Void)?
    /// Widgets: the checkbox runs `ToggleTaskIntent` (the rest of the widget opens the app).
    var togglesWithIntent = false
    /// Smaller checkbox for dense widget timelines.
    var checkboxSize: CGFloat?
    var onOpen: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: tokens.space(.iconTextGap)) {
            checkbox
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
        }
        .opacity(item.isBlocked ? tokens.opacity(.blocked) : 1)
        .contentShape(Rectangle())
        // Everything except the checkbox opens the task (chips included).
        .onTapGesture { onOpen?() }
    }

    private var color: Color { tokens.color(item.isHabit ? .habit : .task) }

    private var chipViews: some View {
        ForEach(chips) { chip in Chip(icon: chip.icon, text: chip.text, tint: chip.tint) }
    }

    @ViewBuilder private var checkbox: some View {
        let glyph = MarkGlyph(state: item.state, color: item.isDone ? tokens.color(.past) : color, showsLock: item.isBlocked,
                              size: checkboxSize)
        if togglesWithIntent {
            Button(intent: ToggleTaskIntent(taskName: item.task.name)) { glyph }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(item.isDone ? "a11y.uncheck" : "a11y.check"))
        } else if let onToggle {
            Button(action: onToggle) { glyph }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(item.isDone ? "a11y.uncheck" : "a11y.check"))
                .accessibilityIdentifier("check:\(item.task.name)")
        } else {
            glyph
        }
    }

    @ViewBuilder private var title: some View {
        let text = Text(item.task.name)
            .font(titleFont ?? tokens.font(.taskTitle))
            .foregroundStyle(item.isDone ? tokens.color(.secondaryText) : tokens.color(.primaryText))
            .multilineTextAlignment(.leading)
            .lineLimit(titleLineLimit ?? (isCompact ? 1 : nil))
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
        if task.isRecurring { result.append(RowChip(id: "habit", icon: .habit, text: nil, tint: tokens.color(.habit))) }
        if let due = task.due, !task.isRecurring, due.day != today || due.time != nil {
            result.append(RowChip(id: "due", icon: .due, text: DueText.format(due, today: today), tint: nil))
        } else if task.isRecurring, let time = task.due?.time {
            result.append(RowChip(id: "due", icon: .time, text: time.string, tint: nil))
        }
        result.append(RowChip(id: "estimate", icon: nil, text: EstimateText.label(task.timeEstimate, rules: rules), tint: nil))
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
    static func format(_ due: TaskDue, today: LocalDate) -> String {
        let distance = today.days(until: due.day)
        let dayText: String
        switch distance {
        case 0: dayText = L10n.string("due.today")
        case 1: dayText = L10n.string("due.tomorrow")
        case -1: dayText = L10n.string("due.yesterday")
        case 2...6: dayText = weekdayName(due.day)
        default: dayText = shortDate(due.day)
        }
        guard let time = due.time else { return dayText }
        return distance == 0 ? time.string : "\(dayText) \(time.string)"
    }

    private static func weekdayName(_ day: LocalDate) -> String {
        let symbols = Calendar(identifier: .gregorian).shortWeekdaySymbols
        return symbols[day.weekday.rawValue % 7]
    }

    private static func shortDate(_ day: LocalDate) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? Date()
        return date.formatted(.dateTime.month(.abbreviated).day())
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
    /// The plate a task row sits on (pool, timeline, widgets).
    func taskPlate() -> some View {
        modifier(TaskPlate())
    }
}

private struct TaskPlate: ViewModifier {
    @Environment(\.tokens) private var tokens

    func body(content: Content) -> some View {
        content
            .padding(.vertical, tokens.space(.rowVertical) / 2)
            .padding(.horizontal, tokens.space(.plateInner) / 2)
            .background(tokens.color(.plateBackground), in: RoundedRectangle(cornerRadius: tokens.radius(.poolRow), style: .continuous))
    }
}
