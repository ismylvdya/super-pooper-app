import SwiftUI

/// Multi-select of calendars or reminder lists with their color dots.
struct SourcePickerScreen: View {
    /// What is picked: each kind knows its texts, what it offers and where the choice is kept.
    enum Kind {
        case calendars
        case reminderLists

        var title: String {
            switch self {
            case .calendars: "settings.calendars"
            case .reminderLists: "settings.reminderLists"
            }
        }

        var hint: LocalizedStringKey {
            switch self {
            case .calendars: "settings.calendars.hint"
            case .reminderLists: "settings.reminderLists.hint"
            }
        }

        /// The picked ids in the settings.
        var selection: WritableKeyPath<AppSettings.Sources, [String]> {
            switch self {
            case .calendars: \.anchorCalendarIDs
            case .reminderLists: \.reminderListIDs
            }
        }

        @MainActor
        func available(in model: AppModel) -> [SourceCollection] {
            switch self {
            case .calendars: model.availableCalendars()
            case .reminderLists: model.availableReminderLists()
            }
        }
    }

    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let kind: Kind

    var body: some View {
        PageScaffold(title: L10n.string(kind.title)) {
            ForEach(groups, id: \.title) { group in
                PlateSection(header: LocalizedStringKey(group.title)) {
                    ForEach(group.items) { item in
                        Button { toggle(item.id) } label: {
                            HStack(spacing: tokens.space(.iconTextGap)) {
                                SourceDot(hex: item.colorHex).frame(width: tokens.size(.iconColumn))
                                Text(item.title).foregroundStyle(tokens.color(.primaryText))
                                Spacer()
                                if selected.contains(item.id) {
                                    Image(systemName: icons[.selected]).foregroundStyle(tokens.color(.accent))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Text(kind.hint)
                .font(tokens.font(.hint))
                .foregroundStyle(tokens.color(.secondaryText))
        }
    }

    private var groups: [(title: String, items: [SourceCollection])] {
        Dictionary(grouping: kind.available(in: model), by: \.sourceTitle).map { ($0.key, $0.value) }.sorted { $0.title < $1.title }
    }

    private var selected: Set<String> {
        Set(model.settings.sources[keyPath: kind.selection])
    }

    private func toggle(_ id: String) {
        Haptics.play(.select)
        model.updateSettings { settings in
            var ids = settings.sources[keyPath: kind.selection]
            if ids.contains(id) { ids.removeAll { $0 == id } } else { ids.append(id) }
            settings.sources[keyPath: kind.selection] = ids
        }
    }
}
