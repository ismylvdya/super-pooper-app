import Foundation

/// How the tasks file is written (`task-file.json`): where it lies in the chosen folder, the titles of its sections, the
/// checkbox of each state and the marker of each field at the end of a task's line.
struct TaskFileFormat: Codable, Hashable, Sendable {
    static let fileName = "task-file.json"

    static func load(bundle: Bundle = .main) throws -> TaskFileFormat {
        try ConfigLoader(bundle: bundle).load(TaskFileFormat.self, from: fileName)
    }

    struct Sections: Codable, Hashable, Sendable {
        let now, soon, halfYear, someday, waiting, done, archive, trash: String
    }

    struct Boxes: Codable, Hashable, Sendable {
        let open, started, done: String
    }

    struct Markers: Codable, Hashable, Sendable {
        let id, date, time, zone, estimate, alarm, high, pleasant, energy, routine, parent, repeats, overdue, completed, deleted: String

        /// Every marker: a task's name cannot hold one.
        var all: [String] { [id, date, time, zone, estimate, alarm, high, pleasant, energy, routine, parent, repeats, overdue, completed, deleted] }
    }

    let folder: String
    let file: String
    let habitsFolder: String
    /// Inside `habitsFolder`: the settings of deleted habits.
    let habitsTrashFolder: String
    let indent: String
    /// The line at the top of the file naming the day its look of today is for (an Obsidian comment, not shown there).
    let dayMarkerPrefix: String
    let dayMarkerSuffix: String
    let sections: Sections
    /// Titles older files have: read as that section and written under its title now.
    let legacySections: [String: TaskSection]
    let boxes: Boxes
    let markers: Markers
    /// Fields older lines have and the app no longer keeps: read so they are no part of the name, and gone with the next write.
    let legacyMarkers: [String]
    /// After the alarm's marker: the sound is the one set in the settings.
    let alarmDefaultSound: String

    func title(of section: TaskSection) -> String {
        switch section {
        case .now: sections.now
        case .soon: sections.soon
        case .halfYear: sections.halfYear
        case .someday: sections.someday
        case .waiting: sections.waiting
        case .done: sections.done
        case .archive: sections.archive
        case .trash: sections.trash
        }
    }
}

/// The sections of the tasks file, in the order a new file has them.
enum TaskSection: String, CaseIterable, Hashable, Codable, Sendable {
    case now, soon, halfYear, someday, waiting, done, archive, trash
}
