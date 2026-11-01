import Foundation

/// What did not happen, in words (problem banners, the vault error screen).
enum FailureText {
    static func describe(_ failure: AppFailure) -> String {
        switch failure {
        case .vaultNotSelected: L10n.string("error.vault.notSelected")
        case .vaultBookmarkInvalid: L10n.string("error.vault.bookmark")
        case .vaultAccessDenied: L10n.string("error.vault.access")
        case .nameTaken(let name): L10n.format("error.rename.taken", name)
        case .invalidName(let name): L10n.format("error.rename.invalid", name)
        case .noteMissing(let name): L10n.format("error.file.missing", name)
        case .writeNotConfirmed(let name): L10n.format("error.write.notConfirmed", name)
        case .eventNotFound: L10n.string("error.event.notFound")
        case .reminderNotFound: L10n.string("error.reminder.notFound")
        case .system(let domain, let code): L10n.format("error.generic", domain, code)
        }
    }
}
