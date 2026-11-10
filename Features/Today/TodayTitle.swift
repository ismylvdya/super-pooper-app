import SwiftUI

/// Today's title: on a backlog page its list's title, plainly; on the day's pages the day's name with its arrows. Both
/// always stand in the same place and change the one way titles change (`titleSwap`), whatever moves the pages.
struct TodayTitle: View {
    @Environment(\.tokens) private var tokens
    let list: BacklogList?
    let dayNavigation: DayNavigation
    let physicalBottom: HorizontalEdge?

    var body: some View {
        let fade = Animation.easeInOut(duration: tokens.duration(.titleSwap))
        ZStack {
            dayNavigation
                .opacity(list == nil ? 1 : 0)
                .animation(fade, value: list == nil)
                .allowsHitTesting(list == nil)
            Text(LocalizedStringKey(list?.title ?? ""))
                .font(tokens.font(.navTitle))
                .lineLimit(1)
                .minimumScaleFactor(physicalBottom != nil ? 1 : tokens.size(.navTitleMin) / tokens.uiFont(.navTitle).pointSize)
                .quarterTurned(physicalBottom)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("today.listTitle")
                .titleSwap(list?.id)
                .opacity(list == nil ? 0 : 1)
                .animation(fade, value: list == nil)
                .allowsHitTesting(false)
        }
        .transaction { $0.animation = nil }
    }
}
