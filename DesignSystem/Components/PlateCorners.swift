import SwiftUI

/// How round each kind of plate is. Every plate takes its corner from here (`plate(_:)`, `plateLift(_:)`), so a radius
/// changes in one place; a plate is never rounder than half its shorter side (`PlateShape`).
enum PlateCorners {
    /// A group of rows: a settings plate, a grouped list's backing and its rows, the habit history.
    case group
    /// One row: a task's plate in the pool, on the timeline and in widgets, a routine's shared plate.
    case row
    /// A row's piece of a shared plate (a habit of a routine): square, the shared plate rounds the ends.
    case piece
    /// An event on the timeline.
    case timelineItem
    /// The frame a live preview sits in on a settings page.
    case previewFrame
    /// A row or a block in the sketch of a settings preview.
    case previewItem
}

extension DesignTokens {
    func plateRadius(_ corners: PlateCorners) -> CGFloat {
        switch corners {
        case .group: radius(.plate)
        case .row: rowPlateRadius
        case .piece: 0
        case .timelineItem: radius(.timelineItem)
        case .previewFrame: radius(.previewFrame)
        case .previewItem: radius(.previewItem)
        }
    }

    func plateShape(_ corners: PlateCorners) -> PlateShape {
        PlateShape(cornerRadius: plateRadius(corners))
    }
}
