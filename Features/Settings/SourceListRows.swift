import SwiftUI

/// The anchor calendars and the "remember at X" reminder lists: a row each with the number chosen, opening
/// the picker. The same rows in Settings and in the last onboarding step.
struct SourceListRows: View {
    @Environment(AppModel.self) private var model
    @Environment(\.icons) private var icons
    @Environment(\.tokens) private var tokens

    var body: some View {
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
    }

    private func count(_ value: Int) -> some View {
        HStack(spacing: tokens.space(.valueChevronGap)) {
            Text(verbatim: "\(value)").foregroundStyle(tokens.color(.secondaryText))
            Image(systemName: icons[.chevron]).foregroundStyle(tokens.color(.tertiaryText))
        }
    }
}
