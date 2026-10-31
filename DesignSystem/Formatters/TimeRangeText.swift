import SwiftUI

enum TimeRangeText {
    static func format(_ start: Date, _ end: Date, calendar: Calendar) -> String {
        let style = Date.FormatStyle(date: .omitted, time: .shortened)
        return L10n.format("common.range", DateText.format(start, style, calendar: calendar), DateText.format(end, style, calendar: calendar))
    }
}
