import Foundation

/// A notification belongs to its logical day: once that day is over it leaves Notification Center (a habit not
/// marked by the boundary does not wait into the next day) and is not put back when swiped away.
enum StaleNotifications {
    static func isOver(_ day: LocalDate?, today: LocalDate) -> Bool {
        day.map { $0 < today } ?? false
    }

    /// The app's delivered notifications (identifier and its day as written in `userInfo`) of days before `today`.
    static func identifiers(_ delivered: [(identifier: String, day: String?)], today: LocalDate) -> [String] {
        delivered.filter { isOver($0.day.flatMap(LocalDate.init(isoString:)), today: today) }.map(\.identifier)
    }
}
