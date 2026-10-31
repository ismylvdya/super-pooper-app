import SwiftUI

/// The room a lifted row gets around a scroll of rows: `top` above the first row, so its shadow fits, and `sides` past
/// the scroll, over the screen margins and the next column. A screen publishes it in the environment (`liftRoom`); the
/// scroll leaves it (`View.liftRoom(extraTop:)`), and what is laid over the scroll reads it from there.
struct LiftRoom: Equatable {
    var top: CGFloat = 0
    var sides: CGFloat = 0
}

private struct LiftRoomKey: EnvironmentKey {
    static let defaultValue = LiftRoom()
}

extension EnvironmentValues {
    /// The room lifted rows get on this screen; none unless the screen gives it.
    var liftRoom: LiftRoom {
        get { self[LiftRoomKey.self] }
        set { self[LiftRoomKey.self] = newValue }
    }
}

extension View {
    /// Lets rows of this scroll view draw over the room around it (`liftRoom` in the environment): a long-pressed plate
    /// grows past the column edge, while the scroll still clips at its top and bottom. `extraTop`: more room above the
    /// content for something laid over it (the all-day strip).
    func liftRoom(extraTop: CGFloat = 0) -> some View {
        modifier(LiftRoomMargins(extraTop: extraTop))
    }
}

private struct LiftRoomMargins: ViewModifier {
    @Environment(\.liftRoom) private var room
    let extraTop: CGFloat

    func body(content: Content) -> some View {
        content
            .contentMargins(.top, room.top + extraTop, for: .scrollContent)
            .scrollClipDisabled()
            .mask(Rectangle().padding(.horizontal, -room.sides))
    }
}
