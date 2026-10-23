import Foundation

/// The emoji a tag starts with (`🔫делишка` → `🔫`), shown as the mark of notes in lists.
enum TagEmoji {
    static func leading(of tag: String) -> String? {
        let trimmed = tag.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        guard let first = trimmed.first, first.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation || $0.properties.generalCategory == .otherSymbol }) else {
            return nil
        }
        return String(first)
    }
}
