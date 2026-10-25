import SwiftUI

enum EstimateText {
    /// Labels come from `rules.json` (`2 min`, `15 min`, `1 h`, `dohuya`); empty = the default estimate.
    static func label(_ minutes: Int?, rules: RulesConfig) -> String {
        let value = (minutes ?? 0) > 0 ? minutes ?? 0 : rules.day.defaultEstimateMinutes
        if let option = rules.timeEstimates.first(where: { $0.minutes == value }) { return L10n.string(option.label) }
        return L10n.format("estimate.minutes", value)
    }
}
