import Foundation

/// When the installed app's signature runs out.
protocol AppSignatureReading: Sendable {
    /// nil when it never runs out or cannot be read.
    func expiration() -> Date?
}

/// The expiration of the provisioning profile inside the app (none in the simulator or an App Store build).
struct ProvisioningProfileSignature: AppSignatureReading {
    func expiration() -> Date? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .isoLatin1),
              let start = text.range(of: "<?xml"), let end = text.range(of: "</plist>"),
              let plist = text[start.lowerBound..<end.upperBound].data(using: .isoLatin1),
              let object = try? PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any]
        else { return nil }
        return object["ExpirationDate"] as? Date
    }
}

/// A signature that runs out at a set moment (DEBUG launch argument, previews and tests).
struct FixedSignature: AppSignatureReading {
    let date: Date?

    func expiration() -> Date? { date }
}
