import Foundation

/// What this device last saw of today's look, in the app group.
struct JSONDayLookMemory: DayLookMemory {
    static let fileName = "day-look.json"
    let store: JSONFileStore

    func load() -> DayLook? { store.read(DayLook.self, from: Self.fileName) }

    func save(_ look: DayLook) { try? store.write(look, to: Self.fileName) }
}
