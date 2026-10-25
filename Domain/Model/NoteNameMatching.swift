import Foundation

extension String {
    /// Note names match like Obsidian links on Apple platforms: case-insensitive, any Unicode form.
    func isSameNoteName(as other: String) -> Bool {
        lowercased() == other.lowercased()
    }
}
