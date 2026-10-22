import Foundation

/// DEBUG-only launch arguments for testing in the simulator (ignored in Release):
/// - `-SPVaultPath <path>`: use this folder as the vault without the picker (relative = inside Documents);
/// - `-SPSeedDemo`: create the demo calendar, events and reminders and select them;
/// - `-SPNow <HH:mm>`: pretend the current time is HH:mm today (the clock keeps ticking);
/// - `-SPSkipOnboarding`: mark onboarding as done;
/// - `-SPResetState`: forget app settings and day state before start;
/// - `-SPTimeline oneColumn|twoColumns`: override the timeline layout;
/// - `-SPOpen <superpooper://…>`: open a deep link after start.
struct LaunchOptions {
    var vaultPath: String?
    var seedDemo = false
    var now: LocalTime?
    var skipOnboarding = false
    var resetState = false
    var timelineLayout: AppSettings.TimelineLayout?
    var openURL: URL?

    static func current(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> LaunchOptions {
        var options = LaunchOptions()
        #if DEBUG
        func value(_ flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        options.vaultPath = value("-SPVaultPath")
        options.seedDemo = arguments.contains("-SPSeedDemo")
        options.now = value("-SPNow").flatMap(LocalTime.init(string:))
        options.skipOnboarding = arguments.contains("-SPSkipOnboarding")
        options.resetState = arguments.contains("-SPResetState")
        options.timelineLayout = value("-SPTimeline").flatMap(AppSettings.TimelineLayout.init(rawValue:))
        options.openURL = value("-SPOpen").flatMap(URL.init(string:))
        #endif
        return options
    }

    func vaultURL() -> URL? {
        guard let vaultPath else { return nil }
        if vaultPath.hasPrefix("/") { return URL(fileURLWithPath: vaultPath, isDirectory: true) }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent(vaultPath, isDirectory: true)
    }
}
