import SwiftUI

/// A page with the manifest title: SF Rounded Bold 34 centered above the content; when it
/// scrolls away, the same title appears in the bar (shrinking to fit between the bar buttons).
struct PageScaffold<Content: View>: View {
    @Environment(\.tokens) private var tokens
    let title: String
    var isNested = true
    /// Replaces the large title (an editable name, for example); the bar title still shows `title`.
    var titleView: AnyView?
    @ViewBuilder let content: Content
    @State private var isLargeTitleVisible = true
    @State private var titleHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: tokens.space(.groupGap)) {
                Group {
                    if let titleView { titleView } else { Text(title) }
                }
                    .font(tokens.font(.pageTitle))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, isNested ? tokens.space(.nestedTitleInset) - tokens.space(.screenHorizontal) : 0)
                    .padding(.top, isNested ? 0 : tokens.space(.nestedTitleLift))
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { titleHeight = $0 }
                content
            }
            .padding(.horizontal, tokens.space(.screenHorizontal))
            .padding(.bottom, tokens.space(.screenBottom))
        }
        .tracksLargeTitle($isLargeTitleVisible, titleHeight: titleHeight)
        .background(tokens.color(.screenBackground))
        .barTitle(title, isHidden: isLargeTitleVisible)
    }
}
