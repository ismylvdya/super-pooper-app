import Foundation

/// A number of one kind in a banner, shown as the kind's icon and the number (the notes a sync found new, changed or
/// removed); the label says it in words for VoiceOver.
struct BannerCount: Hashable, Sendable {
    let icon: Icon
    let value: Int
    let label: String
}
