import SwiftUI

/// The kinds of property chips at the right of a task row; the user sets their order (Settings → Pool).
enum RowChipKind: String, CaseIterable, Hashable, Sendable {
    case problem, feel, habit

    /// The saved order (raw names); kinds it lacks follow in the built-in order, unknown names are skipped.
    static func ordered(_ names: [String]) -> [RowChipKind] {
        let saved = names.compactMap(RowChipKind.init(rawValue:))
        return saved + allCases.filter { !saved.contains($0) }
    }

    /// The looks a chip of this kind can have (a feel chip: the energy one or the heart).
    var looks: [ChipLook] {
        switch self {
        case .problem: [.problem]
        case .feel: [.needEnergy, .pleasant]
        case .habit: [.habit]
        }
    }

    /// The icon of its first look: the widest a layout has to leave room for (the page peek).
    var icon: Icon { looks[0].icon }
}

/// The property chips shown at the right of a task title.
struct RowChip: Identifiable {
    let kind: RowChipKind
    let look: ChipLook

    var id: String { kind.rawValue }

    static func chips(for item: DayItem, order: [RowChipKind]) -> [RowChip] {
        order.compactMap { kind in look(of: kind, for: item).map { RowChip(kind: kind, look: $0) } }
    }

    private static func look(of kind: RowChipKind, for item: DayItem) -> ChipLook? {
        let task = item.task
        switch kind {
        case .problem: return item.problems.isEmpty ? nil : .problem
        case .habit: return task.isHabit ? .habit : nil
        case .feel:
            switch task.feel {
            case .needEnergy: return .needEnergy
            case .pleasant: return .pleasant
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
