import UIKit
import SpriteKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        if let skView = view as? SKView {
            let scene = GameScene(size: skView.bounds.size)
            scene.scaleMode = .resizeFill
            skView.presentScene(scene)
            skView.ignoresSiblingOrder = true
            skView.showsFPS = false
            skView.showsNodeCount = false
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
