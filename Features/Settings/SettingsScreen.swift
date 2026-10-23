import SwiftUI

/// The Settings tab: two entries (tasks and habits), the trash, the clock, then build version and credits.
struct SettingsScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PageScaffold(title: L10n.string("settings.title"), isNested: false) {
            PlateSection(header: nil) {
                SettingsLink(route: .taskSettings, icon: .taskSettings, title: "settings.tasks")
                SettingsLink(route: .habitSettings, icon: .habitSettings, title: "settings.habits")
            }
            PlateSection(header: nil) {
                if !model.conflictedNotes.isEmpty {
                    SettingsLink(route: .conflicts, icon: .problem, title: "conflicts.title", value: "\(model.conflictedNotes.count)")
                }
                SettingsLink(route: .trash, icon: .trash, title: "trash.title", value: model.trashCount.map(String.init))
            }
            ClockSettingsSection()
            #if DEBUG
            DebugSettingsSection()
            #endif
            SettingsFooter()
        }
        .task { await model.refreshAccess() }
        .task { await model.refreshTrash() }
    }
}

/// Settings of the tasks side: sources, day, Today, timeline, pool, appearance, notifications, archive.
struct TaskSettingsScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PageScaffold(title: L10n.string("settings.tasks")) {
            SourcesSettingsSection()
            DaySettingsSection()
            TodaySettingsSection()
            TimelineSettingsSection()
            PoolSettingsSection()
            AppearanceSettingsSection()
            AccentSettingsSection()
            ColorSettingsSection()
            NotificationSettingsSection()
            if model.config.flags.archive, !model.archivedTasks.isEmpty { ArchiveSettingsSection() }
        }
        .task { await model.refreshAccess() }
    }
}

/// A plate row that pushes a page.
struct SettingsLink: View {
    @Environment(\.icons) private var icons
    let route: Route
    let icon: Icon
    let title: LocalizedStringKey
    var value: String?

    var body: some View {
        NavigationLink(value: route) {
            PlateRow(icon: icon, title: title) {
                if let value { Text(verbatim: value).foregroundStyle(.secondary) }
                Image(systemName: icons[.chevron]).foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.link.\(String(describing: route))")
    }
}

struct SettingsFooter: View {
    @Environment(\.tokens) private var tokens

    var body: some View {
        VStack(spacing: 4) {
            Text(L10n.format("settings.version", Bundle.main.marketingVersion, Bundle.main.buildNumber))
            Text("settings.credits")
        }
        .font(tokens.font(.footer))
        .foregroundStyle(tokens.color(.secondaryText))
        .frame(maxWidth: .infinity)
        .padding(.top, tokens.space(.groupGap))
    }
}

extension Bundle {
    var marketingVersion: String { object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?" }
    var buildNumber: String { object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?" }
}

struct PoolSettingsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens

    var body: some View {
        let isActive = model.settings.poolUsesVisibleCount
        PlateSection(header: "settings.pool", hint: isActive ? "settings.pool.hint" : "settings.pool.hint.sideBySide") {
            PlateRow(icon: .poolCount, title: "settings.pool.visible", info: "info.settings.pool.visible") {
                Stepper(value: Binding(get: { model.settings.pool.visibleCount },
                                       set: { value in model.updateSettings { $0.pool.visibleCount = value } }), in: 1...10) {
                    Text(verbatim: "\(model.settings.pool.visibleCount)")
                }
                .fixedSize()
            }
            .disabled(!isActive)
            .opacity(isActive ? 1 : tokens.opacity(.blocked))
        }
    }
}

struct NotificationSettingsSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PlateSection(header: "settings.notifications", hint: "settings.notifications.hint") {
            PlateRow(icon: .notifications, title: "settings.notifications.enabled", info: "info.settings.notifications") {
                Toggle("settings.notifications.enabled", isOn: Binding(
                    get: { model.settings.notifications.enabled },
                    set: { value in model.updateSettings { $0.notifications.enabled = value } }
                ))
                .labelsHidden()
                .disabled(!model.config.flags.notifications)
            }
        }
    }
}

struct ArchiveSettingsSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PlateSection(header: nil) {
            SettingsLink(route: .archive, icon: .archive, title: "archive.title", value: "\(model.archivedTasks.count)")
        }
    }
}

#if DEBUG
/// DEBUG only: creates demo calendar events and reminders in the simulator.
struct DebugSettingsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.icons) private var icons

    var body: some View {
        PlateSection(header: "settings.debug", hint: "settings.debug.hint") {
            Button {
                Task {
                    guard case .success(let container) = AppContainer.shared,
                          let sources = await DemoDataSeeder(eventKit: container.eventKit, calendar: model.calendar, clock: model.clock).seed()
                    else { return }
                    model.updateSettings {
                        $0.sources.anchorCalendarIDs = [sources.calendarID]
                        $0.sources.reminderListIDs = [sources.reminderListID]
                    }
                    await model.sync(announce: true)
                }
            } label: {
                PlateRow(icon: .debugSeed, title: "settings.debug.seed")
            }
            .buttonStyle(.plain)
            NavigationLink(value: Route.debugNotifications) {
                PlateRow(icon: .notifications, title: "settings.debug.notifications")
            }
            .buttonStyle(.plain)
            NavigationLink(value: Route.debugWidgets) {
                PlateRow(icon: .timelineLayout, title: "settings.debug.widgets")
            }
            .buttonStyle(.plain)
        }
    }
}
#endif
