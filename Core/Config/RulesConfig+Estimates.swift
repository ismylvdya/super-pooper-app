import Foundation

extension RulesConfig {
    /// The same four persisted values are available in all estimate pickers.
    func estimateMinutes(_ proposed: Int?) -> Int {
        guard let proposed, timeEstimates.contains(where: { $0.minutes == proposed }) else {
            return day.defaultEstimateMinutes
        }
        return proposed
    }
}
