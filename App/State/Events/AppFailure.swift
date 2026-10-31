import Foundation

/// Something that did not happen, with the facts the words need. The frontend says it (`FailureText`).
enum AppFailure: Equatable, Sendable {
    case vaultNotSelected
    case vaultBookmarkInvalid
    case vaultAccessDenied
    case nameTaken(String)
    case invalidName(String)
    case noteMissing(String)
    /// The change was written, but what was read back does not show it.
    case writeNotConfirmed(String)
    case eventNotFound
    case reminderNotFound
    /// Any other error, by its domain and code: a system error's own text would be in the phone's language.
    case system(domain: String, code: Int)

    init(_ error: Error) {
        switch error {
        case VaultAccessError.notSelected: self = .vaultNotSelected
        case VaultAccessError.bookmarkInvalid: self = .vaultBookmarkInvalid
        case VaultAccessError.accessDenied: self = .vaultAccessDenied
        case TaskStoreError.nameTaken(let name): self = .nameTaken(name)
        case TaskStoreError.invalidName(let name): self = .invalidName(name)
        case TaskStoreError.fileMissing(let name): self = .noteMissing(name)
        case TaskStoreError.notConfirmed(let name): self = .writeNotConfirmed(name)
        case CalendarEditError.eventNotFound: self = .eventNotFound
        case ReminderEditError.reminderNotFound: self = .reminderNotFound
        default: self = .system(domain: (error as NSError).domain, code: (error as NSError).code)
        }
    }
}
