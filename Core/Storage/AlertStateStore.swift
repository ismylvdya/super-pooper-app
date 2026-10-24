import Foundation

/// What the previous notification sync saw: alerts still upcoming then (key → time) and every key known.
/// It tells which alerts were moved into the past or added too late (`LateAlerts`).
struct AlertState: Codable, Equatable, Sendable {
    var pending: [String: Date] = [:]
    var known: [String] = []
}

struct AlertStateStore: Sendable {
    static let fileName = "alert-state.json"

    let store: JSONFileStore

    func load() -> AlertState? { store.read(AlertState.self, from: Self.fileName) }

    func save(_ state: AlertState) throws { try store.write(state, to: Self.fileName) }
}
