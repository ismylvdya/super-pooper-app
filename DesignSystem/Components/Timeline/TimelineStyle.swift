import SwiftUI

/// Visual parameters of a timeline column.
struct TimelineStyle {
    var fonts: TimelineFonts
    /// At least one line of normal text.
    var minimumItemHeight: CGFloat
    /// Tasks get at least their title and chip lines (short tasks still show two lines).
    var minimumTaskHeight: CGFloat?
    var showsHourLabels = true
    /// How far past the timeline's right edge the now line reaches.
    var nowLineOverhang: CGFloat = 0
    /// Tap on an event (the app opens Calendar on that day).
    var onEventTap: ((CalendarEvent) -> Void)?
    /// Long-press menu of an event (asks first).
    var onEventDelete: ((CalendarEvent) -> Void)?
    /// Reminder long-press menu (completes it in Reminders) and tap (opens it in Reminders).
    var onReminderToggle: ((ReminderItem) -> Void)?
    var onReminderTap: ((ReminderItem) -> Void)?
    /// Another day than today has no "now" cursor.
    var showsNow = true
    /// Task rows draw their own plates (and long-press highlight) instead of getting one here.
    var rowsHaveOwnPlates = false
    /// Dense widget timelines: plates with minimal vertical padding.
    var compactPlates = false
    /// Where a dragged task would land (its minutes are shown next to the hours).
    var dropMarker: Date?
    /// The dragged task as it would stand dropped there (`TimelineSlot.landing`), drawn as a faint copy of its plate.
    var dropGhost: TimelineSlot?
    /// What lies under the timeline: events and reminders are backed with it, so an earlier block does not show through
    /// their see-through fill and a long press lifts the whole plate. Nil leaves them see-through (the widget's
    /// background is a gradient).
    var backdrop: Color?
    /// The finer marks of a zoomed-in timeline (the app's own timeline only).
    var gridDetail = TimelineGridDetail.none
}

extension TimelineStyle {
    /// The app's timeline and its settings preview, at the font sizes picked in the settings.
    static func make(_ settings: AppSettings.Timeline, tokens: DesignTokens) -> TimelineStyle {
        let fonts = TimelineFonts.app(settings, tokens: tokens)
        let titleLine = fonts.taskLineHeight + tokens.space(.timelineTitleExtra)
        var style = TimelineStyle(fonts: fonts,
                                  minimumItemHeight: titleLine + tokens.space(.timelineItemPadding),
                                  // As high as the title row plus the plate padding: equal space above and below.
                                  minimumTaskHeight: titleLine + tokens.space(.rowVertical))
        style.backdrop = tokens.color(.screenBackground)
        return style
    }
}
