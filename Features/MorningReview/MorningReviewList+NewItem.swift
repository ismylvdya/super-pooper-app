import ListEngineChumbulev

extension MorningReviewList {
    static let newItemOwner = "review"

    func newItemDropped(_ drop: ListDrop, pool: DayPoolRows, day: LocalDate) {
        let placement: NewItemPlacement
        if let parent = pool.parent(at: drop) {
            placement = .subtask(of: parent, index: drop.indexInParent, day: day)
        } else {
            placement = .pool(order: pool.order(inserting: [TaskDragState.newItemGap], at: drop), section: drop.sectionID, day: day)
        }
        openNewItem(NewItemSeed(kind: .task, placement: placement, estimate: nil))
    }
}
