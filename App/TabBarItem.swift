/// The tab bar's selection: a tab, or the slot the system keeps for its search-role tab, where the "+" stands. The
/// slot never stays selected: choosing it opens the new-item page on the tab that is open.
enum TabBarItem: Hashable {
    case tab(AppTab)
    case newItem

    @MainActor
    static func selection(_ item: TabBarItem, router: Router) {
        switch item {
        case .tab(let tab): router.select(tab)
        case .newItem: router.openNewItem()
        }
    }
}
