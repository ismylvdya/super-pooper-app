import Foundation
import Testing
import UIKit
@testable import SuperPooperApp

/// An SVG file becomes a picture the bar can tint: its shape opaque, the rest transparent.
@MainActor
struct TabBarIconFilesTests {
    private func file(_ text: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".svg")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test func aFileBecomesAPictureOfItsShapeAlone() async throws {
        let url = try file(#"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><rect x="6" y="6" width="12" height="12"/></svg>"#)
        let name = try #require(await TabBarIconFiles.add(from: url, side: 128))
        defer { TabBarIconFiles.remove(name) }
        #expect(TabBarSymbols.exists(name))
        let picture = try #require(TabBarIconFiles.image(name))
        let ink = InkBounds.of(picture, scale: picture.scale)
        #expect(ink.width > 0)
        #expect(ink.width < picture.size.width * 0.75, "the page around the shape stays transparent")
    }

    @Test func whatCannotBeDrawnIsRefused() async throws {
        let url = try file("not a picture")
        #expect(await TabBarIconFiles.add(from: url, side: 128) == nil)
    }

    @Test func aRemovedFileFallsBackToTheAppsSymbol() async throws {
        let url = try file(#"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="6"/></svg>"#)
        let name = try #require(await TabBarIconFiles.add(from: url, side: 128))
        let icons = TestConfig.decode(IconSet.self, "icons.json")
        let key = TabBarSymbols.key(.today, isSelected: false)
        #expect(TabBarSymbols(typed: [key: name], icons: icons).symbol(of: .today, isSelected: false) == name)
        TabBarIconFiles.remove(name)
        #expect(TabBarSymbols(typed: [key: name], icons: icons).symbol(of: .today, isSelected: false) == icons[AppTab.today.icon])
    }
}
