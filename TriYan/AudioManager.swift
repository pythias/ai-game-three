import AVFoundation
import AudioToolbox
import QuartzCore
import SpriteKit

final class AudioManager {
    static let shared = AudioManager()

    private let soundFolder = "SFX"

    private var bgMusicPlayer: AVAudioPlayer?
    private var swipePlayer: AVAudioPlayer?
    private var lastSwipeFeedbackAt: CFTimeInterval = 0
    private var soundIDs: [String: SystemSoundID] = [:]
    private var isMuted: Bool
    private let mutedKey = "settings.audioMuted"
    private let swipeFeedbackInterval: CFTimeInterval = 0.12

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
        playSwipeFeedback(volume: 0.18)
    }

    func playMerge() {
        guard !isMuted else { return }
        playRandomSound(["merge_0", "merge_1", "merge_2", "merge_3", "merge_4", "merge_5"], ext: "wav")
    }

    func playBigMerge() {
        guard !isMuted else { return }
        playRandomSound(["merge_3", "merge_4", "merge_5"], ext: "wav")
    }

    func playSpawn() {
        return
    }

    func playGameOver() {
        guard !isMuted else { return }
        playSound("game_over", ext: "wav")
    }

    func playButton() {
        guard !isMuted else { return }
        playSwipeFeedback(volume: 0.12)
    }

    func playCombo() {
        guard !isMuted else { return }
        playBigMerge()
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
            "game_over",
            "merge_0",
            "merge_1",
            "merge_2",
            "merge_3",
            "merge_4",
            "merge_5"
        ].forEach { name in
            preloadSound(name, ext: "wav")
        }
    }

    private func preloadSound(_ name: String, ext: String) {
        guard let url = bundleURL(for: name, ext: ext) else { return }

        let key = soundKey(name, ext: ext)
        var soundID: SystemSoundID = 0
        let status = AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        if status == kAudioServicesNoError {
            soundIDs[key] = soundID
        } else {
            print("AudioManager: failed to preload \(name) - \(status)")
        }
    }

    private func playSwipeFeedback(volume: Float) {
        let now = CACurrentMediaTime()
        guard now - lastSwipeFeedbackAt >= swipeFeedbackInterval else { return }
        guard let player = swipePlayer ?? makeSwipePlayer() else { return }
        player.volume = volume
        player.currentTime = 0
        player.play()
        swipePlayer = player
        lastSwipeFeedbackAt = now
    }

    private func makeSwipePlayer() -> AVAudioPlayer? {
        guard let url = bundleURL(for: "swipe", ext: "wav") else { return nil }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            print("AudioManager: failed to load swipe - \(error)")
            return nil
        }
    }

    private func playSound(_ name: String, ext: String) {
        let key = soundKey(name, ext: ext)
        guard let soundID = soundIDs[key] else { return }
        AudioServicesPlaySystemSound(soundID)
    }

    private func playRandomSound(_ names: [String], ext: String) {
        guard let name = names.randomElement() else { return }
        playSound(name, ext: ext)
    }

    private func soundKey(_ name: String, ext: String) -> String {
        "\(name).\(ext)"
    }

    private func bundleURL(for name: String, ext: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext, subdirectory: soundFolder)
            ?? Bundle.main.url(forResource: name, withExtension: ext)
    }

    func playSoundViaSKAction(_ name: String, ext: String, in scene: SKScene) {
        guard !isMuted else { return }
        guard bundleURL(for: name, ext: ext) != nil else { return }
        let action = SKAction.playSoundFileNamed("SFX/\(name).\(ext)", waitForCompletion: false)
        scene.run(action)
    }
}
