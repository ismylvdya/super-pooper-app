#if DEBUG
import SwiftUI
import UserNotifications

/// DEBUG only: what is pending in UNUserNotificationCenter and which actions each category has.
struct NotificationsDebugScreen: View {
    @State private var requests: [UNNotificationRequest] = []
    @State private var categories: [UNNotificationCategory] = []

    var body: some View {
        List {
            Section("Categories") {
                ForEach(categories, id: \.identifier) { category in
                    VStack(alignment: .leading) {
                        Text(category.identifier).font(.headline)
                        Text(category.actions.map(\.title).joined(separator: " · ")).font(.footnote)
                    }
                }
            }
            Section("Pending (\(requests.count))") {
                ForEach(requests, id: \.identifier) { request in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(request.content.title).font(.headline)
                        Text("\(request.content.categoryIdentifier) · \(fireDate(request))").font(.footnote)
                        Text(request.identifier).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .task {
            let center = UNUserNotificationCenter.current()
            requests = await center.pendingNotificationRequests().sorted { fireDate($0) < fireDate($1) }
            categories = await center.notificationCategories().sorted { $0.identifier < $1.identifier }
        }
    }

    private func fireDate(_ request: UNNotificationRequest) -> String {
        (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()?.formatted(date: .abbreviated, time: .shortened) ?? "?"
    }
}
#endif
