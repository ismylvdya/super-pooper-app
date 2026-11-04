import Foundation

/// One line of the tasks file: `- [ ] Name 📅 2026-11-04 ⏰ 14:00 ⏳ 60 🔥 🆔 a1b2c3`, the lines indented under it that are
/// not checkboxes (its text), and the checkboxes indented under it (its subtasks).
struct TaskEntry: Equatable, Sendable {
    enum Box: Equatable, Sendable { case open, started, done }

    var box: Box = .open
    var name: String
    var id: String?
    var date: LocalDate?
    var time: LocalTime?
    var zone: String?
    var estimate: Int?
    /// Rings as an alarm: the sound's id, or the format's word for the settings' sound.
    var alarm: String?
    var isHigh = false
    var feel: TaskFeel = .neutral
    var routine: String?
    /// The parent's id, when the line does not stand under its parent (they are in different sections).
    var parent: String?
    var created: LocalDate?
    var completed: LocalDate?
    var deleted: LocalDate?
    var note: [String] = []
    var children: [TaskEntry] = []
}

extension TaskEntry {
    /// The line without its indent, or nil for any other line.
    init?(line: String, format: TaskFileFormat) {
        guard line.hasPrefix("- ["), line.count >= 6 else { return nil }
        let characters = Array(line)
        guard characters[4] == "]", characters[5] == " " else { return nil }
        switch String(characters[3]) {
        case format.boxes.open: box = .open
        case format.boxes.started: box = .started
        case format.boxes.done: box = .done
        default: return nil
        }
        var tokens = String(characters.dropFirst(6)).split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        name = ""
        // Fields stand at the end of the line: the first token from the end that is no field ends them, and a marker in
        // the middle of a name stays part of it.
        let markers = format.markers
        while let last = tokens.last {
            if last == markers.high { isHigh = true } else if last == markers.pleasant { feel = .pleasant } else if last == markers.energy { feel = .needEnergy } else if tokens.count >= 2, read(last, marker: tokens[tokens.count - 2], markers) {
                tokens.removeLast()
            } else if last.isEmpty {
                // A double space or a trailing one.
            } else {
                break
            }
            tokens.removeLast()
        }
        name = tokens.joined(separator: " ")
    }

    /// Takes `value` as the field of `marker`; false when it is no such pair.
    private mutating func read(_ value: String, marker: String, _ markers: TaskFileFormat.Markers) -> Bool {
        switch marker {
        case markers.id: id = value
        case markers.date:
            guard let day = LocalDate(isoString: value) else { return false }
            date = day
        case markers.time:
            guard let clock = LocalTime(string: value) else { return false }
            time = clock
        case markers.zone: zone = value
        case markers.estimate:
            guard let minutes = Int(value) else { return false }
            estimate = minutes
        case markers.alarm: alarm = value
        case markers.routine: routine = value
        case markers.parent: parent = value
        case markers.created:
            guard let day = LocalDate(isoString: value) else { return false }
            created = day
        case markers.completed:
            guard let day = LocalDate(isoString: value) else { return false }
            completed = day
        case markers.deleted:
            guard let day = LocalDate(isoString: value) else { return false }
            deleted = day
        default: return false
        }
        return true
    }

    /// The line without its indent.
    func line(format: TaskFileFormat) -> String {
        let markers = format.markers
        let symbol = switch box {
        case .open: format.boxes.open
        case .started: format.boxes.started
        case .done: format.boxes.done
        }
        var parts = ["- [\(symbol)]", name]
        func add(_ marker: String, _ value: String?) { if let value { parts += [marker, value] } }
        add(markers.date, date?.isoString)
        add(markers.time, time?.string)
        add(markers.zone, zone)
        add(markers.estimate, estimate.map(String.init))
        add(markers.alarm, alarm)
        if isHigh { parts.append(markers.high) }
        switch feel {
        case .pleasant: parts.append(markers.pleasant)
        case .needEnergy: parts.append(markers.energy)
        case .neutral: break
        }
        add(markers.routine, routine)
        add(markers.parent, parent)
        add(markers.created, created?.isoString)
        add(markers.completed, completed?.isoString)
        add(markers.deleted, deleted?.isoString)
        add(markers.id, id)
        return parts.joined(separator: " ")
    }
}
