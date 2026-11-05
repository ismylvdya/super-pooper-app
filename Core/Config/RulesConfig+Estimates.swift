import Foundation

extension RulesConfig {
    /// The rules with the estimates' minutes picked in the settings. An option keeps its own label while it has its own
    /// minutes; the last, which goes by a word, keeps it always. The same minutes twice are one option.
    func withEstimates(_ minutes: [Int]) -> RulesConfig {
        var rules = self
        var seen: Set<Int> = []
        rules.timeEstimates = timeEstimates.enumerated().compactMap { index, option in
            let value = index < minutes.count ? minutes[index] : option.minutes
            guard value > 0, seen.insert(value).inserted else { return nil }
            let keepsLabel = value == option.minutes || index == timeEstimates.count - 1
            return EstimateOption(minutes: value, label: keepsLabel ? option.label : L10n.format("estimate.minutes", value))
        }
        return rules
    }

    /// The options a picker offers for an item with `current` minutes: one set by hand, or before the settings changed, stays there.
    func estimateOptions(including current: Int) -> [EstimateOption] {
        guard !timeEstimates.contains(where: { $0.minutes == current }) else { return timeEstimates }
        return timeEstimates + [EstimateOption(minutes: current, label: L10n.format("estimate.minutes", current))]
    }
}
