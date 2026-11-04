import AVFoundation
import Foundation

/// The phone's own alarm tones, as far as iOS lets an app see them: AlarmKit plays only sounds in the app's bundle or its
/// `Library/Sounds`, so a tone chosen here is copied there in a format it takes. Where the folder cannot be read the
/// list is empty and only the app's own sounds are offered.
enum SystemAlarmSounds {
    private static let cache = Cache()

    private final class Cache: @unchecked Sendable {
        let lock = NSLock()
        var sources: [String: URL]?
    }

    /// The app's sounds and the phone's tones.
    static func all(_ rules: RulesConfig.Alarms) -> [RulesConfig.Alarms.Sound] {
        rules.sounds + sources(rules).keys.sorted().map { id in
            let name = sources(rules)[id]?.deletingPathExtension().lastPathComponent ?? id
            return RulesConfig.Alarms.Sound(id: id, title: name, file: id + ".caf")
        }
    }

    /// Where a tone already copied lies.
    static func installed(_ file: String) -> URL? {
        guard let url = soundsFolder?.appendingPathComponent(file), FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    /// Copies the tone `id` where AlarmKit finds it; nothing for the app's own sounds.
    static func install(_ id: String?, rules: RulesConfig.Alarms) async {
        guard let id, let source = sources(rules)[id], let folder = soundsFolder else { return }
        let target = folder.appendingPathComponent(id + ".caf")
        guard !FileManager.default.fileExists(atPath: target.path) else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let seconds = rules.systemSoundSeconds
        await Task.detached(priority: .userInitiated) { try? convert(source, to: target, seconds: seconds) }.value
    }

    private static var soundsFolder: URL? {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("Sounds", isDirectory: true)
    }

    private static func sources(_ rules: RulesConfig.Alarms) -> [String: URL] {
        cache.lock.lock()
        defer { cache.lock.unlock() }
        if let known = cache.sources { return known }
        // The simulator keeps the phone's folders under its own root.
        let root = ProcessInfo.processInfo.environment["IPHONE_SIMULATOR_ROOT"] ?? ""
        var found: [String: URL] = [:]
        for folder in rules.systemSoundFolders {
            let files = (try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: root + folder), includingPropertiesForKeys: nil)) ?? []
            for file in files where ["m4r", "caf"].contains(file.pathExtension) {
                // A sound's id is one word in the task's line.
                let word = file.deletingPathExtension().lastPathComponent.replacingOccurrences(of: " ", with: "_")
                found[rules.systemSoundPrefix + word] = file
            }
        }
        cache.sources = found
        return found
    }

    /// As linear PCM, no longer than an alarm may ring.
    private static func convert(_ source: URL, to target: URL, seconds: Double) throws {
        let input = try AVAudioFile(forReading: source)
        let format = input.processingFormat
        let output = try AVAudioFile(forWriting: target, settings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: format.sampleRate, AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
        ])
        let frames = AVAudioFrameCount(min(Double(input.length), seconds * format.sampleRate))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
        try input.read(into: buffer, frameCount: frames)
        try output.write(from: buffer)
    }
}
