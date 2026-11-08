import Foundation

/// The user's own lists (`TaskStatus.custom`): made from a task's page, from Select mode or on the Lists page; tasks moved
/// into one together, a list done or deleted whole. Each change of tasks offers Undo in the banner.
extension AppModel {
    /// Every list of the user's own, in the store's order, empty ones too.
    var customLists: [String] { parts.lists.custom }

    func customListContents(_ title: String, query: String) -> TaskListContents { parts.lists.contents(ofCustom: title, query: query) }

    /// The title a new list may take, or nil (empty, or a list or planning level has it already).
    func newListTitle(_ typed: String) -> String? {
        CustomLists.newTitle(typed, existing: customLists, levelTitles: TaskStatus.known.map(StatusText.title))
    }

    /// A new empty list.
    func createList(_ title: String) async { await parts.lists.add(title) }

    /// The tasks go to `status`: a planning level or a list of the user's own (made by this when it is new).
    func moveTasks(_ names: [String], to status: TaskStatus) async {
        let action = config.actions.definition(.moveToList)
        let step = parts.undo.begin(action.id, on: names)
        let today = context().today
        for name in names {
            await parts.writer.edit(name) { TaskMarking(today: today).changes(setting: status, on: $0) }
        }
        if let step { parts.undo.offer(step, trashed: []) }
    }

    /// The selected tasks of `day`'s pool go to `status` (Select mode → Move to list).
    func moveSelected(_ names: Set<String>, on day: LocalDate, to status: TaskStatus) async {
        await moveTasks(poolItems(named: names, on: day).filter { !$0.isHabit }.map(\.id), to: status)
    }

    /// Every task of the list done at once.
    func completeList(_ title: String) async {
        await performOfferingUndo(config.actions.definition(.done), on: names(in: title), day: nil)
    }

    /// The list's tasks go to the trash (Undo brings them back, and the list with them), and the list is gone.
    func deleteList(_ title: String) async {
        let names = names(in: title)
        if !names.isEmpty { await performOfferingUndo(config.actions.definition(.delete), on: names, day: nil) }
        await parts.lists.remove(title)
    }

    private func names(in title: String) -> [String] {
        customListContents(title, query: "").groups.flatMap(\.tasks).map(\.name)
    }
}
