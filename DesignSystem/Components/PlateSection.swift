import SwiftUI

/// A settings-style group: header above, rounded plate with rows, hint below (manifest specs).
struct PlateSection<Content: View>: View {
    let header: Text?
    let info: LocalizedStringKey?
    let hint: Text?
    let content: Content

    init(header: LocalizedStringKey?, info: LocalizedStringKey? = nil, hint: LocalizedStringKey? = nil,
         @ViewBuilder content: () -> Content) {
        self.init(header: header.map { Text($0) }, info: info, hintText: hint.map { Text($0) }, content: content)
    }

    /// A hint already made into text: the user's own words go in `Text(verbatim:)`, so they show as typed
    /// and not as a key or Markdown.
    init(header: LocalizedStringKey?, info: LocalizedStringKey? = nil, hint: Text, @ViewBuilder content: () -> Content) {
        self.init(header: header.map { Text($0) }, info: info, hintText: hint, content: content)
    }

    init(header: Text, info: LocalizedStringKey? = nil, hint: Text? = nil, @ViewBuilder content: () -> Content) {
        self.init(header: header, info: info, hintText: hint, content: content)
    }

    private init(header: Text?, info: LocalizedStringKey?, hintText: Text?, @ViewBuilder content: () -> Content) {
        self.header = header
        self.info = info
        self.hint = hintText
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let header { PlateHeader(title: header, info: info) }
            Plate { content }
            if let hint { PlateHint(text: hint) }
        }
    }
}
