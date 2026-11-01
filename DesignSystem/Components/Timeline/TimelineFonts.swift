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

    /// The app's timeline and its settings preview, at the sizes picked in the settings; the all-day bars a little
    /// smaller than the event titles.
    static func app(_ settings: AppSettings.Timeline, tokens: DesignTokens) -> TimelineFonts {
        let allDaySize = settings.eventFontSize - Double(tokens.size(.allDayFontDelta))
        return TimelineFonts(event: tokens.font(.timelineEvent, size: settings.eventFontSize),
                             eventLineHeight: tokens.uiFont(.timelineEvent, size: settings.eventFontSize).lineHeight,
                             task: tokens.font(.timelineText, size: settings.taskFontSize),
                             taskLineHeight: tokens.uiFont(.timelineText, size: settings.taskFontSize).lineHeight,
                             allDay: tokens.font(.timelineText, size: allDaySize),
                             allDayLineHeight: tokens.uiFont(.timelineText, size: allDaySize).lineHeight)
    }

    /// The Today widget's timeline: its small type for everything.
    static func widget(tokens: DesignTokens) -> TimelineFonts {
        TimelineFonts(event: tokens.font(.widgetEvent), eventLineHeight: tokens.uiFont(.widgetEvent).lineHeight,
                      task: tokens.font(.widgetCaption), taskLineHeight: tokens.uiFont(.widgetCaption).lineHeight,
                      allDay: tokens.font(.widgetCaption), allDayLineHeight: tokens.size(.widgetAllDayLine))
    }
}
