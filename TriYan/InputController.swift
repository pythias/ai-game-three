import UIKit

enum SwipeDirection {
    case east
    case west
    case northeast
    case southwest
    case northwest
    case southeast
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
        onSwipe?(nearestHexDirection(dx: dx, dy: dy))
    }

    private func nearestHexDirection(dx: CGFloat, dy: CGFloat) -> SwipeDirection {
        let angle = atan2(-dy, dx)
        let candidates: [(direction: SwipeDirection, angle: CGFloat)] = [
            (.east, 0),
            (.northeast, .pi / 3),
            (.northwest, 2 * .pi / 3),
            (.west, .pi),
            (.southwest, -2 * .pi / 3),
            (.southeast, -.pi / 3)
        ]

        return candidates.min { lhs, rhs in
            angularDistance(angle, lhs.angle) < angularDistance(angle, rhs.angle)
        }?.direction ?? .east
    }

    private func angularDistance(_ lhs: CGFloat, _ rhs: CGFloat) -> CGFloat {
        let twoPi = CGFloat.pi * 2
        var difference = abs(lhs - rhs).truncatingRemainder(dividingBy: twoPi)
        if difference > .pi {
            difference = twoPi - difference
        }
        return difference
    }
}
