import Foundation

extension AppModel {
    /// The "New in inbox" quick action: a reminder without a date in the inbox list of Reminders.
    @discardableResult
    func addToInbox(_ title: String) -> Bool {
        let text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        let list = config.rules.inbox.listTitle
        do {
            try services.reminders.add(text, toListTitled: list)
            banners.show(L10n.format("banner.inboxAdded", list), style: .success)
            return true
        } catch RemindersError.listNotFound {
            banners.show(L10n.format("banner.inboxListMissing", list), style: .problem)
        } catch {
            banners.show(Self.describe(error), style: .problem)
        }
        return false
    }
}
