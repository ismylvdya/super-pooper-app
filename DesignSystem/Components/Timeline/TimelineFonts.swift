import SwiftUI

/// The fonts of a timeline with their line heights (a title fades on its last line, a block is at least a line high):
/// event titles, task and reminder titles, the all-day bars. The app, its settings preview and the widget each take
/// theirs from here; an event title's weight is its font token's.
struct TimelineFonts {
    var event: Font
    var eventLineHeight: CGFloat
    var task: Font
    var taskLineHeight: CGFloat
    var allDay: Font
    var allDayLineHeight: CGFloat

    /// The app's timeline and its settings preview: tasks, events and all-day bars in one size, picked in the settings.
    static func app(_ settings: AppSettings.Timeline, tokens: DesignTokens) -> TimelineFonts {
        let size = settings.taskFontSize
        let font = tokens.font(.timelineText, size: size)
        let lineHeight = tokens.uiFont(.timelineText, size: size).lineHeight
        return TimelineFonts(event: font, eventLineHeight: lineHeight, task: font, taskLineHeight: lineHeight,
                             allDay: font, allDayLineHeight: lineHeight)
    }

    /// The Today widget's timeline: its small type for everything.
    static func widget(tokens: DesignTokens) -> TimelineFonts {
        TimelineFonts(event: tokens.font(.widgetEvent), eventLineHeight: tokens.uiFont(.widgetEvent).lineHeight,
                      task: tokens.font(.widgetCaption), taskLineHeight: tokens.uiFont(.widgetCaption).lineHeight,
                      allDay: tokens.font(.widgetCaption), allDayLineHeight: tokens.size(.widgetAllDayLine))
    }
}
