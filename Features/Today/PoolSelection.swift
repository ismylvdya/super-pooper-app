import Observation

/// The pool's Select mode: which tasks are picked. While it is on, a tap picks or drops
/// a row, and the bar's buttons act on the picked ones.
@MainActor
@Observable
final class PoolSelection {
    private(set) var isOn = false
    private(set) var names: Set<String> = []

    /// From the bar's "…": nothing picked yet.
    func start() {
        isOn = true
        names = []
    }

    func start(with name: String) {
        isOn = true
        names = [name]
    }

    func toggle(_ name: String) {
        guard isOn else { return }
        if names.contains(name) { names.remove(name) } else { names.insert(name) }
    }

    func isSelected(_ name: String) -> Bool { names.contains(name) }

    func end() {
        isOn = false
        names = []
    }
}
