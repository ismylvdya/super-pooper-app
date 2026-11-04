import AVFoundation

/// Plays a few seconds of a sound while it is being chosen.
@MainActor
enum AlarmSoundPreview {
    private static var player: AVAudioPlayer?

    static func play(_ file: String?, seconds: Double) {
        player?.stop()
        guard let file, let url = Bundle.main.url(forResource: file, withExtension: nil) ?? SystemAlarmSounds.installed(file) else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
        let playing = player
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            playing?.stop()
        }
    }
}
