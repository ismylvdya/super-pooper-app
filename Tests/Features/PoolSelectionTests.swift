import Testing
@testable import SuperPooperApp

/// Select mode's picked tasks: Select starts it with one row, taps pick and drop, Cancel or an action ends it.
@MainActor
struct PoolSelectionTests {
    @Test func startToggleAndEnd() {
        let selection = PoolSelection()
        selection.toggle("Milk")
        #expect(!selection.isOn && selection.names.isEmpty, "a tap outside Select picks nothing")
        selection.start(with: "Milk")
        selection.toggle("Bank")
        #expect(selection.isOn && selection.names == ["Milk", "Bank"])
        selection.toggle("Milk")
        #expect(selection.names == ["Bank"] && selection.isSelected("Bank") && !selection.isSelected("Milk"))
        selection.end()
        #expect(!selection.isOn && selection.names.isEmpty)
    }
}
