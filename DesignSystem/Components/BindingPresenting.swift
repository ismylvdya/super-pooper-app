import SwiftUI

extension Binding where Value == Bool {
    /// True while `item` is set; turning it off clears the item (an alert or dialog shown for an optional item).
    init<Item>(presenting item: Binding<Item?>) {
        self.init(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
    }
}
