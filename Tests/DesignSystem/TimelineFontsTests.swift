import SwiftUI
import Testing
@testable import SuperPooperApp

/// One place for the timeline's fonts: the app, its settings preview and the widget take them from `TimelineFonts`.
struct TimelineFontsTests {
    private let tokens = TestConfig.tokens

    /// One size picked in the settings: tasks, events and all-day bars all stand in it.
    @Test func theAppsFontsFollowTheSettings() {
        var settings = TestConfig.defaults.timeline
        settings.taskFontSize = 14
        let fonts = TimelineFonts.app(settings, tokens: tokens)
        let lineHeight = tokens.uiFont(.timelineText, size: 14).lineHeight
        #expect(fonts.taskLineHeight == lineHeight)
        #expect(fonts.eventLineHeight == lineHeight)
        #expect(fonts.allDayLineHeight == lineHeight)
        #expect(TimelineStyle.make(settings, tokens: tokens).fonts.taskLineHeight == fonts.taskLineHeight)
    }

    /// The widget's event titles are bolder than its other text by their own token, not by a weight added in a view.
    @Test func theWidgetsEventTitlesHaveTheirOwnToken() {
        let fonts = TimelineFonts.widget(tokens: tokens)
        #expect(tokens.uiFont(.widgetEvent).fontDescriptor.symbolicTraits.contains(.traitBold))
        #expect(fonts.eventLineHeight == tokens.uiFont(.widgetEvent).lineHeight)
        #expect(fonts.allDayLineHeight == tokens.size(.widgetAllDayLine))
    }
}
