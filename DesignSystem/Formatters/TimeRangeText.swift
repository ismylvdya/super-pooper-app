import SwiftUI

enum TimeRangeText {
    static func format(_ start: Date, _ end: Date) -> String {
        L10n.format("common.range", start.formatted(date: .omitted, time: .shortened), end.formatted(date: .omitted, time: .shortened))
    }
}
