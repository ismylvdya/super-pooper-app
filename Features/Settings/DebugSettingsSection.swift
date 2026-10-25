import SwiftUI

#if DEBUG
/// DEBUG only: creates demo calendar events and reminders in the simulator.
struct DebugSettingsSection: View {
    @Environment(AppModel.self) private var model

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
