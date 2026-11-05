import Foundation

extension String {
    /// The text with its first `fragment` replaced; throws when there is none, so a test cannot go on checking nothing.
    func replacingOnce(_ fragment: String, with replacement: String) throws -> String {
        guard let range = range(of: fragment) else {
            throw CocoaError(.formatting, userInfo: [NSLocalizedDescriptionKey: "\(fragment) is not in the text"])
        }
        return replacingCharacters(in: range, with: replacement)
    }
}
