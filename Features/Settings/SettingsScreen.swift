import SwiftUI

/// Settings as grouped plates (manifest): Sources, Day, Timeline (with live preview), Pool,
/// Notifications, Archive (only when not empty), then build version and credits.
struct SettingsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens

    var body: some View {
        PageScaffold(title: L10n.string("settings.title")) {
            SourcesSettingsSection()
            DaySettingsSection()
            TimelineSettingsSection()
            PoolSettingsSection()
            NotificationSettingsSection()
            if model.config.flags.archive, !model.archivedTasks.isEmpty { ArchiveSettingsSection() }
            #if DEBUG
            DebugSettingsSection()
            #endif
            SettingsFooter()
        }
        .task { await model.refreshAccess() }
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

    var body: some View {
        PlateSection(header: "settings.pool", hint: "settings.pool.hint") {
            PlateRow(icon: .poolCount, title: "settings.pool.visible", info: "info.settings.pool.visible") {
                Stepper(value: Binding(get: { model.settings.pool.visibleCount },
                                       set: { value in model.updateSettings { $0.pool.visibleCount = value } }), in: 1...10) {
                    Text(verbatim: "\(model.settings.pool.visibleCount)")
                }
                .fixedSize()
            }
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
    @Environment(\.icons) private var icons

    var body: some View {
        PlateSection(header: nil) {
            NavigationLink(value: Route.archive) {
                PlateRow(icon: .archive, title: "archive.title", info: "info.settings.archive") {
                    Text(verbatim: "\(model.archivedTasks.count)").foregroundStyle(.secondary)
                    Image(systemName: icons[.chevron]).foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
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
