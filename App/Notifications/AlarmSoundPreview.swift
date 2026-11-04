import AVFoundation
import AudioToolbox
import UIKit

/// Plays a sound while it is being chosen, by the media volume: until another is chosen, its page is left or the app goes
/// to the background.
@MainActor
enum AlarmSoundPreview {
    /// The system's alarm sound cannot be read: a system sound of its kind stands in for it.
    private static let systemAlarm: SystemSoundID = 1005
    private static var player: AVAudioPlayer?
    private static var observer: NSObjectProtocol?

    static func play(_ file: String?) {
        stop()
        guard let file, let url = Bundle.main.url(forResource: file, withExtension: nil) ?? SystemAlarmSounds.installed(file) else {
            AudioServicesPlaySystemSound(systemAlarm)
            return
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
        observer = observer ?? NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { stop() }
        }
    }

    static func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
