import Foundation

/// Developer-tunable rules (`rules.json`), separate from the UI and from user settings.
struct RulesConfig: Codable, Hashable, Sendable {
    struct EstimateOption: Codable, Hashable, Sendable {
        let minutes: Int
        /// String Catalog key of the label.
        let label: String
    }

    struct Notifications: Codable, Hashable, Sendable {
        /// iOS keeps at most 64 pending local notifications; the signature's hourly ones need their room.
        let limit: Int
        let horizonDays: Int
        /// The user's own picture for habit notifications, in the app group.
        let imageFile: String
        /// The warning that the app's signature runs out comes this many hours before.
        let signingWarningHours: Double
        /// Through that time it comes again every this many hours (the pending ones count towards iOS's 64: `limit`).
        let signingWarningEveryHours: Double
        let signingWarningID: String
        /// The user's picture is scaled down to at most this many pixels on its longer side.
        let imageMaxPixels: Double
        /// A notification swiped away comes back (silently) this long after.
        let restoreDelaySeconds: Double
        /// A pending notification whose fire time is at most this far from the planned one is kept.
        let fireTimeToleranceSeconds: Double
        /// What the settings offer for how long a snooze lasts, in minutes.
        let snoozeChoices: [Int]
    }

    struct Alarms: Codable, Hashable, Sendable {
        /// Folders of the phone where its own tones may be readable.
        let systemSoundFolders: [String]
        /// What a tone's id starts with.
        let systemSoundPrefix: String
        /// How long a tone may ring at most.
        let systemSoundSeconds: Double
        struct Sound: Codable, Hashable, Sendable {
            let id: String
            let title: String
            /// In the app's bundle; absent = the system's alarm sound.
            let file: String?
        }

        let sounds: [Sound]
        /// The sound that rings silently, its own item in the sound menu.
        let vibrateSound: String
        /// How much of a sound plays while it is being chosen.
    }

    struct EventLinks: Codable, Hashable, Sendable {
        /// Range of days searched when resolving `previous_event` / `next_event`.
        let resolveDaysBefore: Int
        let resolveDaysAfter: Int
        /// How many days ahead the event picker lists.
        let pickerDaysAhead: Int
        /// URL prefix that opens Apple Calendar on a date (seconds since 2001 are appended).
        let calendarAppURL: String
        /// URL prefix that opens a reminder in Apple Reminders (its identifier is appended).
        let remindersAppURL: String
    }

    struct Vault: Codable, Hashable, Sendable {
        let downloadTimeoutSeconds: Double
        /// While waiting for iCloud downloads, the files are checked this often.
        let downloadPollSeconds: Double
        /// The JSON file with the app's shared settings, next to the tasks folder.
        let settingsFile: String
        /// The older note with those settings, read until the file exists.
        let settingsNote: String
        /// Where done tasks are moved, next to the tasks folder; Obsidian and TaskNotes are set to skip it.
        let doneFolder: String
        /// The settings note is written this long after the last change.
        let settingsWriteDelaySeconds: Double
        /// A note's modification date further than this from the one the app saw means it was changed elsewhere.
        let modificationToleranceSeconds: Double
    }

    struct Backups: Codable, Hashable, Sendable {
        let keepCount: Int
    }

    struct Timeline: Codable, Hashable, Sendable {
        /// How often "now" moves and chains are re-laid out.
        let refreshSeconds: Double
        /// A Calendar or Reminders change made elsewhere is read this long after it is announced (they come in bursts).
        let externalChangeDelaySeconds: Double
        /// Upper bound for the hours shown in the one-column layout.
        let maxHoursAfter: Int
        /// Another day (swiped to on Today) is shown around this time.
        let otherDayAnchor: LocalTime
        /// A task dropped on the timeline lands on a multiple of this many minutes.
        let dropStepMinutes: Int
        /// How far a pinch scales the hour height: at least `min` and at most `max` times the fitted one.
        let zoom: Limits.Range
        /// The finer marks of a zoomed-in timeline (`TimelineGridDetail`).
        let detail: TimelineGridDetail.Rules
        /// The same with the phone lying sideways, where the column is short.
        let landscapeDetail: TimelineGridDetail.Rules
        /// The quarter labels and the fine lines stand this many minutes apart.
        let quarterMinutes: Int
        let fineLineMinutes: Int
    }

    struct Widgets: Codable, Hashable, Sendable {
        let refreshMinutes: Int
        let entryCount: Int
        /// Hours the one-column timeline shows in the Today widget.
        let timelineHours: Int
        /// The widget timeline starts at most this many hours before now.
        let maxHoursBefore: Int
        /// Background refresh (vault, widgets, notifications) is asked for this often.
        let backgroundRefreshMinutes: Int
        /// The clock widget is given its minutes this far ahead at a time.
        let clockTimelineMinutes: Int
        /// A block on the widget's timeline is at least this long in its scale (more hours, smaller blocks).
        let minimumBlockMinutes: Int
    }

    struct Habits: Codable, Hashable, Sendable {
        /// The habit page grid shows at least this many weeks, and reaches back to the start plus `historyExtraWeeks`.
        let historyMinimumWeeks: Int
        let historyExtraWeeks: Int
        /// Weeks one pull at the top of the history adds.
        let historyPullWeeks: Int
        /// Values a rule starts with when it is switched on.
        let defaultAllowedSkips: Int
        let defaultWeeklyGoal: Int
        let maxAllowedSkips: Int
        /// Bells under a habit's name in the Habits list (one per reminder, up to this many).
        let maxListBells: Int
        let stats: HabitStatsRules
    }

    /// Pool rows of long tasks are taller: extra title lines from this estimate on.
    struct Pool: Codable, Hashable, Sendable {
        struct ExtraLines: Codable, Hashable, Sendable {
            let minutes: Int
            let lines: Int
        }

        let extraLines: [ExtraLines]
        /// A row counts as shown (for the rows left to scroll to) when this share of it is on screen.
        let rowVisibleShare: Double
        /// The ways of showing a high-priority task the settings offer, in their order.
        let highPriorityLooks: [AppSettings.HighPriorityLook]
        /// The sections every day's pool starts with, in their order.
        let defaultSections: [PoolSectionDefinition]

        func validate(file: String) throws {
            let path = "pool.defaultSections"
            let sections = defaultSections
            if sections.isEmpty { throw ConfigError(file: file, path: path, message: "no sections") }
            if Set(sections.map(\.id)).count != sections.count { throw ConfigError(file: file, path: path, message: "section ids repeat") }
            if sections.filter(\.catchesRest).count != 1 {
                throw ConfigError(file: file, path: path, message: "exactly one section needs \"catchesRest\"")
            }
            let routines = sections.compactMap(\.routine)
            if Set(routines).count != routines.count { throw ConfigError(file: file, path: path, message: "a routine has two sections") }
        }

        func extraLines(forEstimate minutes: Int) -> Int {
            extraLines.filter { minutes >= $0.minutes }.map(\.lines).max() ?? 0
        }
    }

    /// When a finger's movement counts as a tap, a swipe or a pull (points, or a share of the width where named so).
    struct Gestures: Codable, Hashable, Sendable {
        /// A touch that moves less than this is still a tap.
        let tapSlop: Double
        /// A drag on Today starts deciding its direction after this distance.
        let daySwipeMinimumDistance: Double
        /// A task's drag whose finger was lifted with no drop ends after this many seconds (a drop ends it at once).
        let dragEndSettleSeconds: Double
        /// The dragged "+" turns Tasks to a neighbouring block only after staying over its edge this long.
        let newItemTurnDwellSeconds: Double
        /// How long a dragged task stays at a page's edge or over a neighbour before Tasks turns to it.
        let pageEdgeDwellSeconds: Double
        /// A drag is sideways when it moves this many times more across than up or down.
        let daySwipeAxisRatio: Double
        /// A sideways drag turns the page past this share of the width, or when flung past `daySwipeFlingShare` of it.
        let daySwipeShare: Double
        let daySwipeFlingShare: Double
        /// A banner pulled up this far, or flung this far, goes away.
        let bannerDismissDistance: Double
        let bannerDismissFling: Double
        /// Pulling a list down this far arms "load more".
        let pullThreshold: Double
        /// Pulling Tasks' first page sideways this far arms opening the next backlog page.
        let sidePullThreshold: Double
        /// How a pull past an edge resists the finger (a scroll view's bounce: the content moves less the further it goes).
        let pullResistance: Double
    }

    struct Banners: Codable, Hashable, Sendable {
        /// A banner hides itself this long after it appears.
        let autoHideSeconds: Double
        /// A banner offering Undo hides itself this long after it appears; then the action stays.
        let undoSeconds: Double
    }

    /// The sketches of the Today arrangements on the settings page.
    struct SettingsPreview: Codable, Hashable, Sendable {
        let poolRows: Int
        let timelineHours: Int
        /// The colors preview: the first rows of today's pool and then its first habits.
        let colorRows: Int
        let colorHabitRows: Int
    }

    /// Heights assumed until the real ones are measured.
    struct LayoutEstimates: Codable, Hashable, Sendable {
        let poolRowHeight: Double
    }

    /// Ranges of the number controls on settings and note pages.
    struct Limits: Codable, Hashable, Sendable {
        struct Range: Codable, Hashable, Sendable {
            let min: Double
            let max: Double
            /// The slider step, when it has one.
            var step: Double?

            var closed: ClosedRange<Double> { min...max }

            /// The value kept within the range.
            func clamped(_ value: Double) -> Double { Swift.min(Swift.max(value, min), max) }

            /// The nearest step (unchanged without one).
            func snapped(_ value: Double) -> Double {
                guard let step, step > 0 else { return value }
                return (value / step).rounded() * step
            }
            var ints: ClosedRange<Int> { Int(min)...Int(max) }
        }

        let poolVisibleCount: Range
        let hoursBefore: Range
        let bellSize: Range
        let bellOpacity: Range
        let fontSize: Range
        let pastOpacity: Range
        /// The share of a plate a started task's fill reaches.
        let startedFillLength: Range
        /// The ring of a habit's day not done or done partly.
        let ringOpacity: Range
        /// How solid the outline of a task picked in Select mode is.
        let selectionOutlineOpacity: Range
        let recurrenceInterval: Range
        /// "Each" day number of a monthly repeat.
        let monthDay: Range
    }

    let day: DayRules
    let timeEstimates: [EstimateOption]
    let notifications: Notifications
    let alarms: Alarms
    /// The plate at the top of Settings that counts down to the end of the app's signature.
    let signingPlate: SigningPlateRules
    let eventLinks: EventLinks
    let vault: Vault
    let backups: Backups
    let timeline: Timeline
    let widgets: Widgets
    let habits: Habits
    /// Values a new date, time, reminder or repeat end starts from.
    /// How the zone lists show a zone.
    struct TimeZones: Codable, Hashable, Sendable {
        /// The zones that come first in their offset, in order.
        let priority: [String]
        /// How many cities a row names.
        let citiesInRow: Int
    }

    struct Editing: Codable, Hashable, Sendable {
        let defaultTime: LocalTime
        /// A new habit reminder comes this long after the last one.
        let nextReminderGapMinutes: Int
        /// The note text is saved this long after typing stops.
        let noteSaveDelaySeconds: Double
        /// A settings change is written and followed (notifications, widgets) this long after the last one: a slider
        /// sends one per step.
        let settingsSaveDelaySeconds: Double
    }

    let pool: Pool
    let limits: Limits
    let editing: Editing
    let timeZones: TimeZones
    let gestures: Gestures
    let banners: Banners
    let settingsPreview: SettingsPreview
    let layoutEstimates: LayoutEstimates
}

/// Order of the pool sort criteria (`sort.json`).
struct SortConfig: Codable, Hashable, Sendable {
    let pool: [PoolSortCriterion]
}
