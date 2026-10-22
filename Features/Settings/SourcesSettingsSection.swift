import SwiftUI

/// Vault folder, anchor calendars, "remember at X" reminder lists and permissions.
struct SourcesSettingsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.icons) private var icons
    @Environment(\.tokens) private var tokens
    @Environment(\.openURL) private var openURL
    @State private var isPickingVault = false

    var body: some View {
        PlateSection(header: "settings.sources", hint: "settings.sources.hint") {
            PlateRow(icon: .vault, title: "settings.vault", info: "info.settings.vault") {
                Button(model.vaultName ?? L10n.string("settings.vault.choose")) { isPickingVault = true }
                    .lineLimit(1)
            }
            NavigationLink { SourcePickerScreen(kind: .calendars) } label: {
                PlateRow(icon: .calendars, title: "settings.calendars", info: "info.settings.calendars") {
                    count(model.settings.sources.anchorCalendarIDs.count)
                }
            }
            .buttonStyle(.plain)
            .disabled(model.access.calendars != .granted)
            NavigationLink { SourcePickerScreen(kind: .reminderLists) } label: {
                PlateRow(icon: .reminderLists, title: "settings.reminderLists", info: "info.settings.reminderLists") {
                    count(model.settings.sources.reminderListIDs.count)
                }
            }
            .buttonStyle(.plain)
            .disabled(model.access.reminders != .granted || !model.config.flags.reminders)
            accessRow(.calendars, "settings.access.calendar", model.access.calendars) { await model.requestCalendarAccess() }
            accessRow(.reminderLists, "settings.access.reminders", model.access.reminders) { await model.requestRemindersAccess() }
            accessRow(.notifications, "settings.access.notifications", model.access.notifications) { await model.requestNotificationAccess() }
        }
        .vaultPicker(isPresented: $isPickingVault)
    }

    private func count(_ value: Int) -> some View {
        HStack(spacing: 6) {
            Text(verbatim: "\(value)").foregroundStyle(tokens.color(.secondaryText))
            Image(systemName: icons[.chevron]).foregroundStyle(tokens.color(.tertiaryText))
        }
    }

    private func accessRow(_ icon: Icon, _ title: LocalizedStringKey, _ access: SourceAccess,
                           request: @escaping () async -> Void) -> some View {
        PlateRow(icon: icon, title: title) {
            switch access {
            case .granted:
                Image(systemName: icons[.permissionGranted]).foregroundStyle(tokens.color(.pleasant))
            case .notDetermined:
                Button("settings.access.allow") { Task { await request() } }
            case .denied:
                Button("settings.access.openSettings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
        }
    }
}

/// Multi-select of calendars or reminder lists with their color dots.
struct SourcePickerScreen: View {
    enum Kind {
        case calendars
        case reminderLists
    }

    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let kind: Kind

    var body: some View {
        PageScaffold(title: L10n.string(kind == .calendars ? "settings.calendars" : "settings.reminderLists")) {
            ForEach(groups, id: \.title) { group in
                PlateSection(header: LocalizedStringKey(group.title)) {
                    ForEach(group.items) { item in
                        Button { toggle(item.id) } label: {
                            HStack(spacing: tokens.space(.iconTextGap)) {
                                SourceDot(hex: item.colorHex).frame(width: tokens.size(.iconColumn))
                                Text(item.title).foregroundStyle(tokens.color(.primaryText))
                                Spacer()
                                if selected.contains(item.id) {
                                    Image(systemName: "checkmark").foregroundStyle(tokens.color(.accent))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Text(kind == .calendars ? "settings.calendars.hint" : "settings.reminderLists.hint")
                .font(tokens.font(.hint))
                .foregroundStyle(tokens.color(.secondaryText))
        }
    }

    private var items: [SourceCollection] {
        kind == .calendars ? model.availableCalendars() : model.availableReminderLists()
    }

    private var groups: [(title: String, items: [SourceCollection])] {
        Dictionary(grouping: items, by: \.sourceTitle).map { ($0.key, $0.value) }.sorted { $0.title < $1.title }
    }

    private var selected: Set<String> {
        Set(kind == .calendars ? model.settings.sources.anchorCalendarIDs : model.settings.sources.reminderListIDs)
    }

    private func toggle(_ id: String) {
        Haptics.play(.light)
        model.updateSettings { settings in
            var ids = kind == .calendars ? settings.sources.anchorCalendarIDs : settings.sources.reminderListIDs
            if ids.contains(id) { ids.removeAll { $0 == id } } else { ids.append(id) }
            if kind == .calendars { settings.sources.anchorCalendarIDs = ids } else { settings.sources.reminderListIDs = ids }
        }
    }
}
