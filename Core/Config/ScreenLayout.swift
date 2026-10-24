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
        let block: String
        let size: Size
        let weight: Double?
    }

    let axis: Axis
    /// Design-token name of the gap between blocks (see `tokens.json` → `spacing`).
    let spacing: String
    let blocks: [Slot]
    /// Each block is a page of the full width, one shown at a time (horizontal axis); `peek` is the size
    /// token of how much of the neighbouring page stays visible at the edge.
    var paged: Bool? = nil
    var peek: String? = nil

    var isPaged: Bool { paged == true }
}
