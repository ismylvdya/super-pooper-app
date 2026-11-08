import Foundation

/// The lists of the Lists tab (`lists.json`): what each holds now, by planning level, and the filed tasks of a list of
/// done ones, read when such a list or its count shows.
@MainActor
final class TaskLists {
    private let tasks: TaskState
    private let store: TaskStore
    private let config: AppConfig
    private let appEvents: AppEventSink

    init(tasks: TaskState, store: TaskStore, config: AppConfig, appEvents: AppEventSink) {
        self.tasks = tasks
        self.store = store
        self.config = config
        self.appEvents = appEvents
    }

    /// The filed tasks, read-only, for the lists of done tasks and their counts.
    func loadFiled() async {
        tasks.setFiled((try? await store.filedTasks()) ?? [])
    }

    /// A list opens: the filed tasks are read when it shows them.
    func open(_ listID: String) async {
        if filter(listID).showsFiled { await loadFiled() }
    }

    func contents(_ filter: TaskListFilter, query: String) -> TaskListContents {
        filter.contents(of: tasks.tasks, filed: tasks.filedTasks, query: query, rules: config.rules.day)
    }

    func contents(of listID: String, query: String) -> TaskListContents {
        contents(filter(listID), query: query)
    }

    func count(of listID: String) -> Int {
        contents(of: listID, query: "").count
    }

    func filter(_ listID: String) -> TaskListFilter {
        config.lists.list(listID)?.filter ?? TaskListFilter()
    }

    // MARK: - The user's own lists

    /// Every list of the user's own, empty ones too.
    var custom: [String] { CustomLists.titles(stored: tasks.storedLists, tasks: tasks.tasks) }

    func contents(ofCustom title: String, query: String) -> TaskListContents {
        contents(TaskListFilter(statuses: [.custom(title)]), query: query)
    }

    /// A new empty list in the store; nothing when the store keeps no lists of its own.
    func add(_ title: String) async {
        guard let keeper = store as? CustomListKeeping else { return }
        tasks.setStoredLists(tasks.storedLists + [title])
        do { try await keeper.addList(title) } catch { appEvents.send(.failure(AppFailure(error))) }
    }

    /// The list's title leaves the store (its tasks are gone from it already).
    func remove(_ title: String) async {
        guard let keeper = store as? CustomListKeeping else { return }
        tasks.setStoredLists(tasks.storedLists.filter { $0 != title })
        do { try await keeper.removeList(title) } catch { appEvents.send(.failure(AppFailure(error))) }
    }
}
