import Foundation

/// Whole-number amounts from the smallest selectable amount to the configured maximum.
struct HabitQuantity: Hashable, Codable, Sendable {
    static let minimum = 2
    var maximum: Int
    var step: Int

    var isValid: Bool { step > 0 && maximum >= step }

    func accepts(_ value: Int) -> Bool {
        isValid && value >= Self.minimum && value <= maximum && (value == maximum || (value - Self.minimum).isMultiple(of: step))
    }

    var values: [Int] {
        guard isValid, maximum >= Self.minimum else { return [] }
        let stepped = Array(stride(from: Self.minimum, through: maximum, by: step))
        return stepped.last == maximum ? stepped : stepped + [maximum]
    }
}

/// A day's result in Quantity mode. An unmarked day has no entry.
enum HabitQuantityEntry: Hashable, Sendable, Codable {
    case amount(Int)
    case partial

    var amount: Int? {
        if case .amount(let amount) = self { return amount }
        return nil
    }

    var mark: HabitMark? {
        switch self {
        case .partial: .partial
        case .amount(let amount): amount > 0 ? .done : nil
        }
    }

    var field: String {
        switch self {
        case .amount(let amount): String(amount)
        case .partial: HabitMark.partial.rawValue
        }
    }

    init?(field: String) {
        if field == HabitMark.partial.rawValue { self = .partial }
        else if let amount = Int(field), amount >= 0 { self = .amount(amount) }
        else { return nil }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let amount = try? container.decode(Int.self) {
            self = .amount(amount)
        } else if let entry = Self(field: try container.decode(String.self)) {
            self = entry
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid habit quantity entry")
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .amount(let amount): try container.encode(amount)
        case .partial: try container.encode(field)
        }
    }
}
