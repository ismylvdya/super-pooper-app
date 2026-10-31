import SwiftUI
import Testing
@testable import SuperPooperApp

/// One place for the timeline's fonts: the app, its settings preview and the widget take them from `TimelineFonts`.
struct TimelineFontsTests {
    private let tokens = TestConfig.tokens

    /// The sizes picked in the settings; the all-day bars a little smaller than the event titles.
    @Test func theAppsFontsFollowTheSettings() {
        var settings = TestConfig.defaults.timeline
        settings.eventFontSize = 20
        settings.taskFontSize = 14
        let fonts = TimelineFonts.app(settings, tokens: tokens)
        #expect(fonts.eventLineHeight == tokens.uiFont(.timelineEvent, size: 20).lineHeight)
        #expect(fonts.taskLineHeight == tokens.uiFont(.timelineText, size: 14).lineHeight)
        #expect(fonts.allDayLineHeight == tokens.uiFont(.timelineText, size: 20 - Double(tokens.size(.allDayFontDelta))).lineHeight)
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
