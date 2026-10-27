import SwiftUI

/// The kinds of property chips at the right of a task row; the user sets their order (Settings → Pool).
enum RowChipKind: String, CaseIterable, Hashable, Sendable {
    case problem, blocked, high, feel, habit

    /// The saved order (raw names); kinds it lacks follow in the built-in order, unknown names are skipped.
    static func ordered(_ names: [String]) -> [RowChipKind] {
        let saved = names.compactMap(RowChipKind.init(rawValue:))
        return saved + allCases.filter { !saved.contains($0) }
    }
}

/// The property chips shown at the right of a task title.
struct RowChip: Identifiable {
    let kind: RowChipKind
    let icon: Icon?
    let text: String?
    let tint: Color?

    var id: String { kind.rawValue }

    static func chips(for item: DayItem, order: [RowChipKind], tokens: DesignTokens) -> [RowChip] {
        order.compactMap { chip(kind: $0, for: item, tokens: tokens) }
    }

    private static func chip(kind: RowChipKind, for item: DayItem, tokens: DesignTokens) -> RowChip? {
        let task = item.task
        switch kind {
        case .problem:
            return item.problems.isEmpty ? nil : RowChip(kind: kind, icon: .problem, text: nil, tint: tokens.color(.problem))
        case .blocked:
            return item.isBlocked ? RowChip(kind: kind, icon: .links, text: nil, tint: nil) : nil
        case .high:
            return task.isHighPriority ? RowChip(kind: kind, icon: .high, text: nil, tint: tokens.color(.high)) : nil
        case .habit:
            return task.isHabit ? RowChip(kind: kind, icon: .habit, text: nil, tint: tokens.color(.habit)) : nil
        case .feel:
            switch task.feel {
            case .needEnergy: return RowChip(kind: kind, icon: .energy, text: nil, tint: tokens.color(.energy))
            case .pleasant: return RowChip(kind: kind, icon: .pleasant, text: nil, tint: tokens.color(.heart))
            case .neutral: return nil
            }
        }
    }
}

private struct ChipOrderKey: EnvironmentKey {
    static let defaultValue = RowChipKind.allCases
}

extension EnvironmentValues {
    /// The order of the chips in task rows (from the settings).
    var chipOrder: [RowChipKind] {
        get { self[ChipOrderKey.self] }
        set { self[ChipOrderKey.self] = newValue }
    }
}
