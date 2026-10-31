import Foundation

/// Calendar and Reminders edits made elsewhere (moved, deleted, completed) and the app's own reach the timeline and the
/// notifications while the app runs. A burst of store changes (an iCloud sync of many events, one edit that posts
/// several notices) is read once, after the store has been quiet for `timeline.externalChangeDelaySeconds`.
extension AppModel {
    func observeSourceChanges() {
        guard sourceObservers.isEmpty else { return }
        sourceObservers = [services.calendars.changes(), services.reminders.changes()].map { changes in
            Task { [weak self] in
                for await _ in changes { self?.sourcesDidChange() }
            }
        }
    }

    func sourcesDidChange() {
        sourcesRefresh?.cancel()
        sourcesRefresh = Task {
            try? await delay.wait(config.rules.timeline.externalChangeDelaySeconds)
            guard !Task.isCancelled else { return }
            await refreshCalendarSources()
            await publishDerivedState()
        }
    }

    /// A notification action run in the background waits for the read it caused before the app is suspended.
    func waitForSourceRefresh() async {
        // A notice that came in meanwhile started the wait again.
        while let refresh = sourcesRefresh {
            await refresh.value
            if sourcesRefresh == refresh { break }
        }
        await waitForNotifications()
    }
}
