import Foundation

/// Renders the test vault templates (`Fixtures/TestVault`) for a given "today", so fixture dates
/// never go stale. Foundation only: the same file is compiled into the unit tests and into
/// `scripts/render-test-vault.sh`.
///
/// Placeholders:
/// - `{{date:+N}}` → `YYYY-MM-DD` of today + N days;
/// - `{{weekday:fri}}` → that weekday of the current Monday–Sunday week;
/// - `{{compact:-N}}` → `YYYYMMDD` (for `DTSTART`);
/// - `{{stamp:-N}}` → a TaskNotes timestamp `YYYY-MM-DDT09:12:44.123+HH:MM`;
/// - `{{eventlink:Title|+N HH:mm}}` → `fixture-event|Title|<ISO start>` (resolved by title and time).
struct TestVaultRenderer {
    let today: Date
    let calendar: Calendar

    init(year: Int, month: Int, day: Int, timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2
        self.calendar = calendar
        self.today = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date()
    }

    init(today: Date, timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: today)
        self.init(year: parts.year ?? 2026, month: parts.month ?? 1, day: parts.day ?? 1, timeZone: timeZone)
    }

    func render(_ template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\\{\\{(\\w+):([^}]*)\\}\\}") else { return template }
        var result = template
        let matches = regex.matches(in: template, range: NSRange(template.startIndex..., in: template))
        for match in matches.reversed() {
            guard let whole = Range(match.range, in: template), let kind = Range(match.range(at: 1), in: template),
                  let argument = Range(match.range(at: 2), in: template) else { continue }
            result.replaceSubrange(whole, with: value(String(template[kind]), String(template[argument])))
        }
        return result
    }

    /// Copies `source` to `destination`, rendering every `.md` file.
    func renderVault(from source: URL, to destination: URL) throws {
        let manager = FileManager.default
        if manager.fileExists(atPath: destination.path) { try manager.removeItem(at: destination) }
        try manager.createDirectory(at: destination, withIntermediateDirectories: true)
        guard let enumerator = manager.enumerator(at: source, includingPropertiesForKeys: [.isDirectoryKey]) else { return }
        for case let url as URL in enumerator {
            let relative = String(url.standardizedFileURL.path.dropFirst(source.standardizedFileURL.path.count + 1))
            let target = destination.appendingPathComponent(relative)
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                try manager.createDirectory(at: target, withIntermediateDirectories: true)
            } else if url.pathExtension == "md" {
                let text = try String(contentsOf: url, encoding: .utf8)
                try render(text).write(to: target, atomically: true, encoding: .utf8)
            } else {
                try manager.copyItem(at: url, to: target)
            }
        }
    }

    // MARK: - Placeholders

    private func value(_ kind: String, _ argument: String) -> String {
        switch kind {
        case "date": return format(day(argument), "yyyy-MM-dd")
        case "compact": return format(day(argument), "yyyyMMdd")
        case "weekday": return format(weekday(argument), "yyyy-MM-dd")
        case "stamp": return format(day(argument).addingTimeInterval(-3 * 3600 + 12 * 60 + 44.123), "yyyy-MM-dd'T'HH:mm:ss.SSSxxx")
        case "eventlink":
            let parts = argument.split(separator: "|", maxSplits: 1).map(String.init)
            let when = (parts.last ?? "").split(separator: " ").map(String.init)
            let time = (when.last ?? "00:00").split(separator: ":").compactMap { Int($0) }
            let base = calendar.startOfDay(for: day(when.first ?? "+0"))
            let start = base.addingTimeInterval(Double((time.first ?? 0) * 3600 + (time.last ?? 0) * 60))
            return "fixture-event|\(parts.first ?? "")|\(format(start, "yyyy-MM-dd'T'HH:mm:ssxxx"))"
        default: return "{{\(kind):\(argument)}}"
        }
    }

    private func day(_ offset: String) -> Date {
        let days = Int(offset.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "+", with: "")) ?? 0
        return calendar.date(byAdding: .day, value: days, to: today) ?? today
    }

    private func weekday(_ name: String) -> Date {
        let order = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
        let target = order.firstIndex(of: name.lowercased()) ?? 0
        let current = (calendar.component(.weekday, from: today) + 5) % 7
        return calendar.date(byAdding: .day, value: target - current, to: today) ?? today
    }

    private func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
