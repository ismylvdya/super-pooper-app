import Foundation

/// The parts behind the app model, wired once for the app, the previews and the tests. Leaf state first (settings, the
/// day, the tasks, Calendar and Reminders), then what is derived from it, then the commands and the sync that change it.
@MainActor
struct AppParts {
    /// What the parts talk to (repositories and the store).
    let services: AppServices
    /// What the task store can do beyond the basics.
    let capabilities: StoreCapabilities
    let settings: SettingsController
    let day: DayStateController
    let sections: DaySectionsController
    let tasks: TaskState
    /// Finds dates typed into names (`date-grammar.json`).
    let dates: DateDetector
    let sources: SourcesController
    let derived: DerivedStatePublisher
    let writer: NoteWriter
    let texts: NoteTextEditor
    let notes: NoteCommands
    let undo: UndoController
    let dayCommands: DayCommands
    let sourceCommands: SourceCommands
    let lists: TaskLists
    let trash: TrashController
    let conflicts: ConflictResolver
    let picture: NotificationPictureController
    let signing: SigningController
    let sync: SyncService

    init(config: AppConfig, services: AppServices, appEvents: AppEventSink, clock: Clock, calendar: CalendarSource, delay: Delay) {
        self.services = services
        capabilities = StoreCapabilities(opensExternally: services.links != nil, hasTrash: services.trash != nil)
        let rules = config.rules
        let store = services.tasks
        let backups = BackupPolicy(isOn: config.flags.backups, backups: services.backups)
        settings = SettingsController(store: services.settingsStore, note: services.settingsNote, rules: rules, delay: delay)
        day = DayStateController(clock: clock, calendar: calendar, store: services.dayStateStore, settings: settings)
        sections = DaySectionsController(store: services.daySectionStore, day: day, definitions: rules.pool.defaultSections)
        tasks = TaskState()
        dates = DateDetector(grammar: config.dateGrammar)
        sources = SourcesController(calendars: services.calendars, reminders: services.reminders,
                                    notifications: services.notifications, config: config, settings: settings, day: day)
        derived = DerivedStatePublisher(config: config, tasks: tasks, day: day, sections: sections, sources: sources,
                                        settings: settings, services: services)
        writer = NoteWriter(tasks: tasks, store: store, day: day, derived: derived, backups: backups, appEvents: appEvents,
                            filesDoneTasks: config.flags.fileDoneTasks)
        texts = NoteTextEditor(tasks: tasks, store: store, appEvents: appEvents, delay: delay,
                               saveDelay: rules.editing.noteSaveDelaySeconds)
        undo = UndoController(tasks: tasks, writer: writer, store: store, trash: services.trash, day: day, sections: sections,
                              derived: derived, appEvents: appEvents)
        dayCommands = DayCommands(day: day, sections: sections, tasks: tasks, writer: writer, derived: derived, appEvents: appEvents)
        notes = NoteCommands(tasks: tasks, writer: writer, texts: texts, store: store, links: services.links, backups: backups,
                             settings: settings, day: day, sections: sections, derived: derived, appEvents: appEvents, dates: dates,
                             placements: dayCommands)
        sourceCommands = SourceCommands(sources: sources, services: services, day: day, derived: derived, appEvents: appEvents,
                                        delay: delay, quietSeconds: rules.timeline.externalChangeDelaySeconds)
        lists = TaskLists(tasks: tasks, store: store, config: config)
        trash = TrashController(trash: services.trash, tasks: tasks, store: store, derived: derived, appEvents: appEvents)
        conflicts = ConflictResolver(versions: services.versions, tasks: tasks, store: store, backups: backups, derived: derived,
                                     appEvents: appEvents)
        picture = NotificationPictureController(images: services.notificationImage, settings: settings, derived: derived,
                                                appEvents: appEvents)
        signing = SigningController(signature: services.signature, clock: clock, rules: rules.signingPlate)
        sync = SyncService(config: config, services: services, tasks: tasks, settings: settings, day: day, sources: sources,
                           writer: writer, texts: texts, derived: derived, backups: backups, appEvents: appEvents, dayCommands: dayCommands)
        settings.observer = sync
    }
}
