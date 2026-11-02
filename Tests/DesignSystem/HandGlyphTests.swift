import Foundation
import Testing
import SwiftUI
import UIKit
@testable import SuperPooperApp

/// The hand-drawn glyphs: the Lists icon picked in the settings stands within the other tabs' symbols, and Need energy
/// is the frog wherever the property shows.
@MainActor
struct HandGlyphTests {
    private let icons = TestConfig.decode(IconSet.self, "icons.json")
    private let tokens = TestConfig.tokens
    private let scale: CGFloat = 3

    private func config() throws -> AppConfig { try AppConfig.load() }

    @Test func inkBoundsFindWhereAnImageDraws() {
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10), format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 2, y: 3, width: 4, height: 5))
        }
        #expect(InkBounds.of(image, scale: 2) == CGRect(x: 2, y: 3, width: 4, height: 5))
        let empty = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4), format: format).image { _ in }
        #expect(InkBounds.of(empty, scale: 2) == .zero)
    }

    @Test func theListsIconChoicesAreTheGunsWithTheGunByDefault() throws {
        let lists = try config().lists
        #expect(lists.icons.map(\.id) == ["gun", "gunFill", "doubleGuns", "doubleGunsFillForward", "doubleGunsFillBack"])
        #expect(TestConfig.defaults.lists.icon == "gun")
        #expect(lists.icon(for: TestConfig.defaults.lists.icon) == .listsGun)
        #expect(lists.icon(for: "doubleGunsFillBack") == .listsDoubleGunsFillBack)
        #expect(lists.icon(for: "pistol") == .listsGun, "an id no choice has any more gets the first one")
        let bundle = Bundle.main
        let titles = lists.icons.map { bundle.localizedString(forKey: $0.title, value: "∅", table: nil) }
        #expect(titles == ["Gun", "Gun fill", "Double guns", "Double guns fill forward", "Double guns fill back"])
        for choice in lists.icons {
            #expect(TemplateGlyph.asset(icons[choice.icon]) != nil, "\(choice.id) is a template asset")
            #expect(UIImage(named: icons[choice.icon])?.renderingMode == .alwaysTemplate, "\(choice.id) is tinted like a symbol")
        }
    }

    @Test func aDefaultListsIconNoChoiceHasIsAConfigError() throws {
        let lists = try config().lists
        #expect(throws: ConfigError.self) { try lists.validate(defaultIcon: "pistol", file: "lists.json") }
        #expect(throws: Never.self) { try lists.validate(defaultIcon: "doubleGuns", file: "lists.json") }
    }

    /// The pick is kept in the settings and synced with the vault like the others; a settings file of an older version
    /// gets the gun.
    @Test func thePickedListsIconIsKeptInTheSettings() async throws {
        let model = try #require(PreviewModel.make()).model
        #expect(model.listsIcon == .listsGun)
        model.updateSettings { $0.lists.icon = "doubleGunsFillForward" }
        #expect(model.listsIcon == .listsDoubleGunsFillForward)
        #expect(AppTab.lists.icon(lists: model.listsIcon) == .listsDoubleGunsFillForward)
        #expect(AppTab.today.icon(lists: model.listsIcon) == .tabToday)
        await model.parts.settings.waitForSave()
        #expect(model.parts.services.settingsStore.load().lists.icon == "doubleGunsFillForward")
        #expect(SyncedSettings(model.settings).lists.icon == "doubleGunsFillForward")

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = JSONFileStore(directory: directory)
        try store.writeData(Data(#"{"appearance": {"pastOpacity": 0.5}}"#.utf8), to: SettingsStore.fileName)
        #expect(SettingsStore(store: store, defaults: try config().defaultSettings).load().lists.icon == "gun")
    }

    /// Upright the glyph is no taller than any other tab's symbol, sideways no wider: whichever gun is picked.
    @Test func theListsGlyphStandsWithinTheOtherTabSymbols() throws {
        let lists = try config().lists
        let fit = tokens.bar(.tabGlyphFit)
        let cases: [(font: UIFont, axis: Axis)] = [(tokens.uiFont(.systemTabIcon), .vertical), (tokens.uiFont(.tabIcon), .horizontal)]
        for choice in lists.icons {
            let others = icons.otherTabSymbols(than: .lists, lists: choice.icon)
            #expect(others.count == AppTab.allCases.count - 1)
            for (font, axis) in cases {
                let inks = others.compactMap { UIImage(systemName: $0, withConfiguration: UIImage.SymbolConfiguration(font: font)) }
                    .map { InkBounds.of($0, scale: scale) }
                #expect(inks.count == others.count)
                let extent = TabIconImage.glyphExtent(font: font, others: others, along: axis, fit: fit, scale: scale)
                let glyph = try #require(TemplateGlyph.image(icons[choice.icon], extent: extent, along: axis, scale: scale))
                let side = axis == .vertical ? glyph.size.height : glyph.size.width
                #expect(abs(side - extent) < 1 / scale, "\(choice.id): the glyph is cut to its ink")
                for ink in inks {
                    #expect(side <= (axis == .vertical ? ink.height : ink.width) + 1 / scale, "\(choice.id) \(axis)")
                }
            }
        }
    }

    /// Need energy is the frog: its chip in rows, the review and the chip order, its list in Lists, the page's chips.
    @Test func needEnergyIsTheFrog() throws {
        #expect(ChipLook.needEnergy.icon == .energy)
        #expect(RowChipKind.feel.icon == .energy)
        #expect(try config().lists.list("energy")?.icon == .energy)
        #expect(icons[.energy] == "NeedEnergyFrog")
        #expect(UIImage(named: icons[.energy])?.renderingMode == .alwaysTemplate)
        #expect(UIImage(systemName: icons[.energy]) == nil)
        #expect(!Icon.allCases.map { icons[$0] }.contains("bolt.fill"), "no lightning left for Need energy")
        let font = tokens.uiFont(.chip)
        let frog = IconGlyph.size(of: .energy, font: font, tokens: tokens, icons: icons, scale: scale)
        #expect(abs(frog.height - font.capHeight * tokens.ratio(.handGlyph)) < 1 / scale)
        #expect(frog.height < tokens.chipHeight, "the frog fits its chip")
        #expect(Chip.width(of: RowChipKind.feel.icon, tokens: tokens, icons: icons, scale: scale)
                == frog.width + ChipCapsule.standard.horizontalPadding(tokens) * 2)
    }
}
