import Foundation

/// What the app state tells the user about, in its own terms. The app state never puts it in words: the frontend
/// decides the text, the look and where a tap leads (`BannerPresenter`).
enum AppEvent: Equatable, Sendable {
    case created(String)
    case renamed(String)
    case archived(String)
    case deleted(String)
    /// A note put back from the trash, under the name it got there.
    case restored(String)
    case deletedForever(String)
    /// Tasks of later planning levels that joined this week (by the user or by auto-promotion).
    case promoted([String])
    /// The fields an edit wrote that had also been changed elsewhere to something else (the edit won).
    case fieldsClashed(note: String, fields: [TaskField])
    /// Notes with conflicting versions, waiting for the user to pick one.
    case conflictsFound([String])
    case conflictResolved(String)
    /// What a sync the user asked for changed, per kind.
    case synced(added: Int, changed: Int, removed: Int)
    /// The day has more problems than the user was last told about.
    case problemsFound(Int)
    /// The folder chosen is a whole vault rather than its tasks folder.
    case wholeVaultChosen
    /// The manual order of today's pool was dropped for the automatic sort.
    case orderReset
    /// A new note was not created: its name cannot be used.
    case nameRejected(NoteNameProblem, name: String)
    case notificationImageFailed
    case failure(AppFailure)
}

/// Where the app state sends its events (the frontend's banner presenter; a recorder in tests).
@MainActor
protocol AppEventSink: AnyObject {
    func send(_ event: AppEvent)
}

extension AppEvent {
    /// Merged edits are silent; fields changed both here and elsewhere are reported.
    static func clashes(in result: TaskWriteResult, of name: String) -> AppEvent? {
        result.clashingFields.isEmpty ? nil : .fieldsClashed(note: name, fields: result.clashingFields)
    }
}
