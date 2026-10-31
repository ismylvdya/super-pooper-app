import Foundation

/// What the pickers of the task page offer, and the event a link of the page stands for.
extension AppModel {
    /// The events of the next days to link a task to, by day (`rules.eventLinks.pickerDaysAhead`).
    func pickableEvents(matching query: String) -> [EventPicking.Day] {
        EventPicking.days(events, matching: query, daysAhead: config.rules.eventLinks.pickerDaysAhead, context: context())
    }

    /// The tasks and habits a note can be linked to.
    func linkCandidates(excluding excluded: Set<String>, matching query: String) -> [TaskItem] {
        LinkCandidates.tasks(tasks, excluding: excluded, matching: query)
    }

    /// The calendar event a task's link points to, as the day finds it (`EventLinkResolver`); nil when it is not there.
    func event(for link: EventLink) -> CalendarEvent? {
        EventLinkResolver(events: events, calendar: calendar).resolve(link)
    }
}
