import Foundation
import Observation

/// The store's trash, where it has one: the notes in it, a note's text, putting one back among the tasks, deleting one
/// for good. Without a trash the app has no trash screen.
@MainActor
@Observable
final class TrashController {
    private(set) var notes: [TrashedNote] = []
    @ObservationIgnored private let trash: TaskTrash?
    @ObservationIgnored private let tasks: TaskState
    @ObservationIgnored private let store: TaskStore
    @ObservationIgnored private let derived: DerivedStatePublisher
    @ObservationIgnored private let appEvents: AppEventSink

    init(trash: TaskTrash?, tasks: TaskState, store: TaskStore, derived: DerivedStatePublisher, appEvents: AppEventSink) {
        self.trash = trash
        self.tasks = tasks
        self.store = store
        self.derived = derived
        self.appEvents = appEvents
    }

    /// Re-reads the trash (the trash screen and the Settings counter).
    func refresh() async {
        notes = (try? await trash?.notes()) ?? []
    }

    func text(of note: TrashedNote) async -> String {
        (try? await trash?.text(of: note)) ?? ""
    }

    func restore(_ note: TrashedNote) async {
        do {
            guard let trash else { return }
            appEvents.send(.restored(try await trash.restore(note)))
            await tasks.reload(from: store)
            await derived.publish()
        } catch {
            appEvents.send(.failure(AppFailure(error)))
        }
        await refresh()
    }

    func deletePermanently(_ note: TrashedNote) async {
        do {
            try await trash?.deletePermanently(note)
            appEvents.send(.deletedForever(note.name))
        } catch {
            appEvents.send(.failure(AppFailure(error)))
        }
        await refresh()
    }
}
