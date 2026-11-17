import Foundation

/// How the tasks file is written (`task-file.json`): where it lies in the chosen folder, the titles of its sections, the
/// checkbox of each state and the marker of each field at the end of a task's line.
struct TaskFileFormat: Codable, Hashable, Sendable {
    static let fileName = "task-file.json"

    static func load(bundle: Bundle = .main) throws -> TaskFileFormat {
        try ConfigLoader(bundle: bundle).load(TaskFileFormat.self, from: fileName)
    }

    struct Sections: Codable, Hashable, Sendable {
        let soon, halfYear, someday, done, archive, trash: String
    }

    /// How a line says it is in today's pool and in which of its sections (`TodayPool`, `PoolSectionTag`): marks with the
    /// swimmer, no hashtags (D-187).
    struct Pool: Codable, Hashable, Sendable {
        /// The mark of a task in today's pool.
        let tag: String
        /// The mark of a task kept out of tomorrow's pool in the morning review planned the day before.
        let notTomorrowTag: String
        /// A section's mark is this and the section's word.
        let sectionPrefix: String
        /// The sections a task stays in from day to day; the tags of the others go with the day's turn.
        let lastingSections: [String]
        /// The section of the rest: a line in it names none.
        let restSection: String
    }

    /// The pool's marks as an older file wrote them (`#in_today_pool`, `#not_tomorrow`, `#section_…`): still read, written
    /// anew in the marks of `Pool` with the next write, the file kept as it was in a backup first.
    struct LegacyPool: Codable, Hashable, Sendable {
        let tag: String
        let notTomorrowTag: String
        let sectionPrefix: String
    }

    struct Boxes: Codable, Hashable, Sendable {
        let open, started, done: String
    }

    struct Markers: Codable, Hashable, Sendable {
        let id, date, time, alarm, ringtone, zone, estimate, high, pleasant, energy, routine, parent, steps, project, repeats, overdue, completed, deleted: String

        /// Every marker: a task's name cannot hold one.
        var all: [String] { [id, date, time, alarm, ringtone, zone, estimate, high, pleasant, energy, routine, parent, steps, project, repeats, overdue, completed, deleted] }
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
    /// Titles of the section of today older files have (format 2): its lines join Next actions in today's pool, each
    /// group under it becoming the tag of its section.
    let legacyTodaySections: [String]
    let pool: Pool
    let legacyPool: LegacyPool
    let boxes: Boxes
    let markers: Markers
    /// Fields older lines have and the app no longer keeps: read so they are no part of the name, and gone with the next write.
    let legacyMarkers: [String]
    /// What older lines (and a warning sign typed without its emoji form) say High priority with; written as `markers.high` next.
    let legacyHighMarkers: [String]
    /// After the alarm's marker: the sound is the one set in the settings.
    let alarmDefaultSound: String
    /// A comment line a file of this format starts with. A file without it is older, and there `markers.alarm` before a time meant
    /// only a time, and an alarm stood apart under `legacyAlarmMarker`.
    let formatMarker: String
    let legacyAlarmMarker: String
    /// What an older line says Started with; it is `boxes.started` now.
    let legacyStartedMarker: String
    /// Done has a file of its own next to the tasks.
    let doneFile: String
    /// Words older lines end with and the app no longer keeps: read so they are no part of the name, and gone with the next write.
    let legacyWords: [String]

    /// The word of a line that says it is in today's pool, in the marks of now or of an older file.
    func isPoolMark(_ word: String) -> Bool { word == pool.tag || word == legacyPool.tag }

    /// The word of a line that says it is kept out of tomorrow, now or in an older file.
    func isNotTomorrowMark(_ word: String) -> Bool { word == pool.notTomorrowTag || word == legacyPool.notTomorrowTag }

    /// The pool section a word names, now or in an older file; nil for any other word.
    func poolSection(in word: String) -> String? {
        for prefix in [pool.sectionPrefix, legacyPool.sectionPrefix] where word.hasPrefix(prefix) && word.count > prefix.count {
            return String(word.dropFirst(prefix.count))
        }
        return nil
    }

    /// The text has a pool mark of an older file: the next write gives it the marks of now.
    func hasLegacyPoolMarks(_ text: String) -> Bool {
        text.contains(" " + legacyPool.tag) || text.contains(" " + legacyPool.notTomorrowTag) || text.contains(" " + legacyPool.sectionPrefix)
    }

    func title(of section: TaskSection) -> String {
        switch section {
        case .soon: sections.soon
        case .halfYear: sections.halfYear
        case .someday: sections.someday
        case .done: sections.done
        case .archive: sections.archive
        case .trash: sections.trash
        }
    }
}

/// The sections of the tasks file, in the order a new file has them.
enum TaskSection: String, CaseIterable, Hashable, Codable, Sendable {
    case soon, halfYear, someday, archive, trash, done
}
