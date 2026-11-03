import Foundation

/// The words and formats inline date detection understands (`date-grammar.json`), English as the app's interface.
/// Words are matched whole and regardless of case.
struct DateGrammar: Decodable, Hashable, Sendable {
    enum Unit: String, Decodable, CaseIterable, Sendable, CodingKeyRepresentable {
        case minute, hour, day
    }

    /// "in" of "in 5 min".
    let relativePrefix: [String]
    let units: [Unit: [String]]
    let today: [String]
    let tomorrow: [String]
    let nextWeek: [String]
    let weekdays: [Weekday: [String]]
    /// Month 1…12 → its names; a name counts only next to a day number.
    let months: [Int: [String]]
    /// "at" of "at 6".
    let at: [String]
    let am: [String]
    let pm: [String]
    /// Between day, month and year of "6.11" and "06.11.2026".
    let dateSeparators: [String]
    /// Between hours and minutes of "18:20".
    let timeSeparator: String

    private enum CodingKeys: String, CodingKey {
        case relativePrefix, units, today, tomorrow, nextWeek, weekdays, months, at, am, pm, dateSeparators, timeSeparator
    }

    init(from decoder: Decoder) throws {
        try decoder.rejectUnknownKeys(CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        relativePrefix = try container.decode([String].self, forKey: .relativePrefix)
        units = try container.decode([Unit: [String]].self, forKey: .units)
        today = try container.decode([String].self, forKey: .today)
        tomorrow = try container.decode([String].self, forKey: .tomorrow)
        nextWeek = try container.decode([String].self, forKey: .nextWeek)
        let named = try container.decode([String: [String]].self, forKey: .weekdays)
        var weekdays: [Weekday: [String]] = [:]
        for (name, words) in named {
            guard let weekday = Weekday.allCases.first(where: { $0.configName == name }) else {
                throw DecodingError.dataCorruptedError(forKey: .weekdays, in: container, debugDescription: "unknown weekday \"\(name)\"")
            }
            weekdays[weekday] = words
        }
        self.weekdays = weekdays
        months = try container.decode([Int: [String]].self, forKey: .months)
        at = try container.decode([String].self, forKey: .at)
        am = try container.decode([String].self, forKey: .am)
        pm = try container.decode([String].self, forKey: .pm)
        dateSeparators = try container.decode([String].self, forKey: .dateSeparators)
        timeSeparator = try container.decode(String.self, forKey: .timeSeparator)
    }

    /// Every unit, weekday and month has a word, and no word means two things.
    func validate(file: String) throws {
        for unit in Unit.allCases where (units[unit] ?? []).isEmpty {
            throw ConfigError(file: file, path: "units.\(unit.rawValue)", message: "no words")
        }
        for weekday in Weekday.allCases where (weekdays[weekday] ?? []).isEmpty {
            throw ConfigError(file: file, path: "weekdays.\(weekday.configName)", message: "no words")
        }
        if months.keys.sorted() != Array(1...12) || months.values.contains(where: \.isEmpty) {
            throw ConfigError(file: file, path: "months", message: "every month 1…12 needs its words")
        }
        if dateSeparators.isEmpty || timeSeparator.isEmpty {
            throw ConfigError(file: file, path: "dateSeparators", message: "no separator")
        }
        var seen: [String: String] = [:]
        for (group, words) in wordGroups {
            for word in words.map({ $0.lowercased() }) {
                if let other = seen[word], other != group {
                    throw ConfigError(file: file, path: group, message: "\"\(word)\" is also in \(other)")
                }
                seen[word] = group
            }
        }
    }

    private var wordGroups: [(String, [String])] {
        var groups: [(String, [String])] = [("relativePrefix", relativePrefix), ("today", today), ("tomorrow", tomorrow),
                                            ("nextWeek", nextWeek), ("at", at), ("am", am), ("pm", pm)]
        groups += Unit.allCases.map { ("units.\($0.rawValue)", units[$0] ?? []) }
        groups += Weekday.allCases.map { ("weekdays.\($0.configName)", weekdays[$0] ?? []) }
        groups += months.keys.sorted().map { ("months.\($0)", months[$0] ?? []) }
        return groups
    }
}

extension Weekday {
    /// The weekday as configs name it ("monday").
    var configName: String {
        switch self {
        case .monday: "monday"
        case .tuesday: "tuesday"
        case .wednesday: "wednesday"
        case .thursday: "thursday"
        case .friday: "friday"
        case .saturday: "saturday"
        case .sunday: "sunday"
        }
    }
}
