import Foundation

/// Deep-merges JSON objects: values from `overlay` win, keys missing there keep their defaults.
enum JSONMerge {
    static func merge(base: Data, overlay: Data) throws -> Data {
        let baseObject = try JSONSerialization.jsonObject(with: base)
        let overlayObject = try JSONSerialization.jsonObject(with: overlay)
        return try JSONSerialization.data(withJSONObject: merge(baseObject, overlayObject), options: [.sortedKeys])
    }

    private static func merge(_ base: Any, _ overlay: Any) -> Any {
        guard let baseDict = base as? [String: Any], let overlayDict = overlay as? [String: Any] else { return overlay }
        var result = baseDict
        for (key, value) in overlayDict {
            result[key] = baseDict[key].map { merge($0, value) } ?? value
        }
        return result
    }
}
