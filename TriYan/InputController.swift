import UIKit

enum SwipeDirection {
    case up, down, left, right
}

final class InputController: NSObject {
    var onSwipe: ((SwipeDirection) -> Void)?

    private weak var view: UIView?
    private var panRecognizer: UIPanGestureRecognizer?

    init(view: UIView) {
        self.view = view
        super.init()
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)
        panRecognizer = pan
    }

    deinit {
        if let r = panRecognizer {
            view?.removeGestureRecognizer(r)
        }
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard recognizer.state == .ended else { return }

        let translation = recognizer.translation(in: view)
        let dx = translation.x
        let dy = translation.y
        let threshold: CGFloat = 10

        guard max(abs(dx), abs(dy)) >= threshold else { return }

        if abs(dx) > abs(dy) {
            onSwipe?(dx > 0 ? .right : .left)
        } else {
            onSwipe?(dy > 0 ? .down : .up)
        }
    }
}
