import UIKit

enum SwipeDirection {
    case up, down, left, right
}

final class InputController: NSObject {
    var onSwipe: ((SwipeDirection) -> Void)?

    private weak var view: UIView?
    private var panRecognizer: UIPanGestureRecognizer?
    private var hasTriggeredSwipe = false

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
        switch recognizer.state {
        case .began:
            hasTriggeredSwipe = false
        case .changed, .ended:
            guard !hasTriggeredSwipe else { return }
        default:
            hasTriggeredSwipe = false
            return
        }

        let translation = recognizer.translation(in: view)
        let dx = translation.x
        let dy = translation.y
        let threshold: CGFloat = 18

        guard max(abs(dx), abs(dy)) >= threshold else { return }

        hasTriggeredSwipe = true
        if abs(dx) > abs(dy) {
            onSwipe?(dx > 0 ? .right : .left)
        } else {
            onSwipe?(dy > 0 ? .down : .up)
        }
    }
}
