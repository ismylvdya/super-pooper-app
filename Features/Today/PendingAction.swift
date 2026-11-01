import SwiftUI

struct PendingAction: Identifiable, Equatable {
    let action: ActionDefinition
    let taskName: String
    var id: String { "\(action.id.rawValue)|\(taskName)" }
}
