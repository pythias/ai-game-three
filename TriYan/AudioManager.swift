import AVFoundation
import AudioToolbox
import SpriteKit

final class AudioManager {
    static let shared = AudioManager()

    private var bgMusicPlayer: AVAudioPlayer?
    private var soundIDs: [String: SystemSoundID] = [:]
    private var isMuted: Bool
    private let mutedKey = "settings.audioMuted"

    private init() {
        isMuted = UserDefaults.standard.bool(forKey: mutedKey)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        preloadSoundEffects()
    }

    deinit {
        soundIDs.values.forEach { AudioServicesDisposeSystemSoundID($0) }
    }

    // MARK: - Background Music

    func playBackgroundMusic() {
        guard !isMuted else { return }
        guard bgMusicPlayer == nil else { return }

        guard let url = Bundle.main.url(forResource: "bgm", withExtension: "mp3") else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0.3
            player.prepareToPlay()
            player.play()
            bgMusicPlayer = player
        } catch {
            print("AudioManager: failed to play bgm - \(error)")
        }
    }

    func stopBackgroundMusic() {
        bgMusicPlayer?.stop()
        bgMusicPlayer = nil
    }

    // MARK: - Sound Effects

    func playMove() {
        guard !isMuted else { return }
        playSound("move", ext: "wav")
    }

    func playMerge() {
        guard !isMuted else { return }
        playSound("merge", ext: "wav")
    }

    func playBigMerge() {
        guard !isMuted else { return }
        playSound("combo", ext: "wav")
    }

    func playSpawn() {
        guard !isMuted else { return }
        playSound("spawn", ext: "wav")
    }

    func playGameOver() {
        guard !isMuted else { return }
        playSound("gameover", ext: "wav")
    }

    func playButton() {
        guard !isMuted else { return }
        playSound("move", ext: "wav", volume: 0.35)
    }

    func playCombo() {
        guard !isMuted else { return }
        playSound("combo", ext: "wav")
    }

    // MARK: - Mute

    func toggleMute() {
        isMuted.toggle()
        UserDefaults.standard.set(isMuted, forKey: mutedKey)
        if isMuted {
            bgMusicPlayer?.volume = 0
        } else {
            bgMusicPlayer?.volume = 0.3
        }
    }

    var muted: Bool { isMuted }

    // MARK: - Private

    private func preloadSoundEffects() {
        [
            ("move", "wav"),
            ("merge", "wav"),
            ("combo", "wav"),
            ("spawn", "wav"),
            ("gameover", "wav")
        ].forEach { name, ext in
            preloadSound(name, ext: ext)
        }
    }

    private func preloadSound(_ name: String, ext: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return }

        let key = soundKey(name, ext: ext)
        var soundID: SystemSoundID = 0
        let status = AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        if status == kAudioServicesNoError {
            soundIDs[key] = soundID
        } else {
            print("AudioManager: failed to preload \(name) - \(status)")
        }
    }

    private func playSound(_ name: String, ext: String, volume: Float = 0.6) {
        let key = soundKey(name, ext: ext)
        guard let soundID = soundIDs[key] else { return }
        AudioServicesPlaySystemSound(soundID)
    }

    private func soundKey(_ name: String, ext: String) -> String {
        "\(name).\(ext)"
    }

    func playSoundViaSKAction(_ name: String, ext: String, in scene: SKScene) {
        guard !isMuted else { return }
        guard Bundle.main.url(forResource: name, withExtension: ext) != nil else { return }
        let action = SKAction.playSoundFileNamed("\(name).\(ext)", waitForCompletion: false)
        scene.run(action)
    }
}
