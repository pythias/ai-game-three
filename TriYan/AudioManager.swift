import AVFoundation
import SpriteKit

final class AudioManager {
    static let shared = AudioManager()

    private var bgMusicPlayer: AVAudioPlayer?
    private var isMuted = false

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
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
        playSound("bigmerge", ext: "wav")
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
        playSound("button", ext: "wav")
    }

    func playCombo() {
        guard !isMuted else { return }
        playSound("combo", ext: "wav")
    }

    // MARK: - Mute

    func toggleMute() {
        isMuted.toggle()
        if isMuted {
            bgMusicPlayer?.volume = 0
        } else {
            bgMusicPlayer?.volume = 0.3
        }
    }

    var muted: Bool { isMuted }

    // MARK: - Private

    private func playSound(_ name: String, ext: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 0.6
            player.prepareToPlay()
            player.play()
        } catch {
            print("AudioManager: failed to play \(name) - \(error)")
        }
    }

    func playSoundViaSKAction(_ name: String, ext: String, in scene: SKScene) {
        guard !isMuted else { return }
        guard Bundle.main.url(forResource: name, withExtension: ext) != nil else { return }
        let action = SKAction.playSoundFileNamed("\(name).\(ext)", waitForCompletion: false)
        scene.run(action)
    }
}
