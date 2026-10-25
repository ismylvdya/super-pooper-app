import SwiftUI

/// The property chips shown under a task title.
struct RowChip: Identifiable {
    let id: String
    let icon: Icon?
    let text: String?
    let tint: Color?

    static func chips(for item: DayItem, today: LocalDate, rules: RulesConfig, tokens: DesignTokens) -> [RowChip] {
        let task = item.task
        var result: [RowChip] = []
        if !item.problems.isEmpty { result.append(RowChip(id: "problem", icon: .problem, text: nil, tint: tokens.color(.problem))) }
        if item.isBlocked { result.append(RowChip(id: "blocked", icon: .links, text: nil, tint: nil)) }
        if task.isHighPriority { result.append(RowChip(id: "high", icon: .high, text: nil, tint: tokens.color(.high))) }
        if task.isHabit { result.append(RowChip(id: "habit", icon: .habit, text: nil, tint: tokens.color(.habit))) }
        if task.needEnergy { result.append(RowChip(id: "energy", icon: .energy, text: nil, tint: tokens.color(.energy))) }
        if task.pleasant == true { result.append(RowChip(id: "pleasant", icon: .pleasant, text: nil, tint: tokens.color(.heart))) }
        return result
    }
}
