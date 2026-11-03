import Foundation

/// Where the app's shared settings live in the vault (see `VaultSettingsFile`).
protocol SettingsNoteRepository: Sendable {
    func read() async -> Data?
    func write(_ json: Data) async throws
}
