import SwiftUI

/// How a task, habit or repeatable task feels. Need energy, neutral in the middle, pleasant: the system's segmented
/// control, with an icon for each.
struct FeelPicker: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.displayScale) private var displayScale
    let editor: TaskEditor

    var body: some View {
        PlateRow(icon: .feel, title: "taskPage.feel") {
            Picker("taskPage.feel", selection: Binding(get: { editor.task.feel }, set: { feel in
                Haptics.play(.select)
                editor.apply([.feel(feel)])
            })) {
                ForEach(TaskFeel.allCases, id: \.self) { feel in
                    image(of: feel).accessibilityLabel(Text(title(of: feel))).tag(feel)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: tokens.size(.feelPicker))
            .accessibilityIdentifier("taskPage.feel")
        }
    }

    /// In its own color: a segment draws a plain image in one tint.
    private func image(of feel: TaskFeel) -> Image {
        let font = tokens.uiFont(.toggleChip)
        let extent = font.capHeight * tokens.ratio(.handGlyph)
        let configuration = UIImage.SymbolConfiguration(font: font)
        let picture: UIImage?
        switch feel {
        case .needEnergy:
            picture = TemplateGlyph.image(icons[.energy], extent: extent, along: .vertical, scale: displayScale)?
                .withTintColor(UIColor(tokens.color(.energy)), renderingMode: .alwaysOriginal)
        case .neutral:
            picture = UIImage(systemName: icons[.feelNeutral], withConfiguration: configuration)
        case .pleasant:
            picture = UIImage(systemName: icons[.pleasant], withConfiguration: configuration)?
                .withTintColor(UIColor(tokens.color(.heart)), renderingMode: .alwaysOriginal)
        }
        return picture.map(Image.init(uiImage:)) ?? Image(systemName: icons[.feelNeutral])
    }

    private func title(of feel: TaskFeel) -> LocalizedStringKey {
        switch feel {
        case .needEnergy: "lists.energy"
        case .neutral: "taskPage.feel.neutral"
        case .pleasant: "lists.pleasant"
        }
    }
}
