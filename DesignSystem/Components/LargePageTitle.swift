import SwiftUI

/// The large title at the top of a page (manifest: SF Rounded Bold 34, centred). A tab's own page has it a little
/// lower; a pushed page keeps it clear of the bar buttons. It reports its height for `titleScrollsIntoBar`.
struct LargePageTitle<Title: View>: View {
    @Environment(\.tokens) private var tokens
    var isNested = true
    @Binding var height: CGFloat
    @ViewBuilder let title: Title

    var body: some View {
        title
            .font(tokens.font(.pageTitle))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, isNested ? tokens.space(.nestedTitleInset) - tokens.space(.screenHorizontal) : 0)
            .padding(.top, isNested ? 0 : tokens.space(.nestedTitleLift))
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
    }
}
