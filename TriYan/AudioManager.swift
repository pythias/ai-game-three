import AVFoundation
import SpriteKit

final class AudioManager: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioManager()

    private var bgMusicPlayer: AVAudioPlayer?
    private var soundPlayers: [AVAudioPlayer] = []
    private var isMuted = false

    private override init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        super.init()
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
        if isMuted {
            bgMusicPlayer?.volume = 0
        } else {
            bgMusicPlayer?.volume = 0.3
        }
    }

    var muted: Bool { isMuted }

    // MARK: - Private

    private func playSound(_ name: String, ext: String, volume: Float = 0.6) {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.volume = volume
            player.prepareToPlay()
            player.play()
            soundPlayers.append(player)
        } catch {
            print("AudioManager: failed to play \(name) - \(error)")
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        soundPlayers.removeAll { $0 === player }
    }

    func playSoundViaSKAction(_ name: String, ext: String, in scene: SKScene) {
        guard !isMuted else { return }
        guard Bundle.main.url(forResource: name, withExtension: ext) != nil else { return }
        let action = SKAction.playSoundFileNamed("\(name).\(ext)", waitForCompletion: false)
        scene.run(action)
    }
}
