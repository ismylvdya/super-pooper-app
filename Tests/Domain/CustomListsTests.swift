import Foundation
import Testing
@testable import SuperPooperApp

/// Lists of the user's own: which there are and what a new one may be called.
@Suite("Custom lists")
struct CustomListsTests {
    @Test func theStoresListsThenTheOnesTasksStandInAlready() {
        let tasks = [makeTask("Gift", status: .custom("Trip")), makeTask("Fix bike", status: .custom("Garage")), makeTask("Read")]
        #expect(CustomLists.titles(stored: ["Garage", "Empty"], tasks: tasks) == ["Garage", "Empty", "Trip"])
    }

    @Test func aNewTitleIsTrimmedAndNotOneTakenAlready() {
        #expect(CustomLists.newTitle("  Trip to Masha ", existing: [], levelTitles: ["Someday"]) == "Trip to Masha")
        #expect(CustomLists.newTitle("   ", existing: [], levelTitles: []) == nil)
        #expect(CustomLists.newTitle("trip", existing: ["Trip"], levelTitles: []) == nil)
        #expect(CustomLists.newTitle("someday", existing: [], levelTitles: ["Someday"]) == nil)
    }
}
