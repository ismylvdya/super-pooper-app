import Foundation

/// A data-driven screen layout: which blocks, in what order, along which axis, how much space.
/// Blocks know nothing about their position; the layout knows nothing about block contents.
struct ScreenLayout: Codable, Hashable, Sendable {
    enum Axis: String, Codable, Sendable {
        case vertical
        case horizontal
    }

    enum Size: String, Codable, Sendable {
        /// The block takes its ideal length along the axis.
        case fit
        /// The block shares the remaining space with other `fill` blocks by `weight`.
        case fill
    }

    struct Slot: Codable, Hashable, Sendable {
        let block: TodayBlockID
        let size: Size
        let weight: Double?
    }

    let axis: Axis
    /// Design-token name of the gap between blocks (see `tokens.json` → `spacing`).
    let spacing: String
    let blocks: [Slot]
    /// Each block is a page of almost the full width, one shown at a time (horizontal axis); how much of the other page
    /// stays in sight is the settings' (`PagePeeks`, D-191).
    var paged: Bool? = nil
    /// Pages of half the width, two in sight side by side (landscape): the shown page on the left, the next one on the
    /// right — the pool and the timeline, or a list and the page after it (D-191).
    var halves: Bool? = nil

    var isPaged: Bool { paged == true }
    var isHalves: Bool { isPaged && halves == true }

    /// The gap's name must be a design token, so a typo stops the app with the file and the key instead of silently
    /// becoming a zero gap.
    func validate(file: String) throws {
        if SpacingToken(rawValue: spacing) == nil {
            throw ConfigError(file: file, path: "spacing", message: "unknown spacing token \"\(spacing)\"")
        }
    }
}

/// The blocks a Today layout places (`block` in `layouts/today-*.layout.json`).
enum TodayBlockID: String, Codable, CaseIterable, Sendable {
    case pool, timeline
}
