import UIKit

final class InputController: NSObject {
    var onSwipe: ((MoveDirection) -> Void)?

    private weak var view: UIView?
    private var recognizers: [UISwipeGestureRecognizer] = []

    init(view: UIView) {
        self.view = view
        super.init()
        installRecognizers(on: view)
    }

    deinit {
        recognizers.forEach { recognizer in
            view?.removeGestureRecognizer(recognizer)
        }
    }

    private func installRecognizers(on view: UIView) {
        let pairs: [(UISwipeGestureRecognizer.Direction, MoveDirection)] = [
            (.up, .up),
            (.down, .down),
            (.left, .left),
            (.right, .right)
        ]

        for pair in pairs {
            let recognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
            recognizer.direction = pair.0
            recognizer.cancelsTouchesInView = true
            recognizer.name = directionName(for: pair.1)
            view.addGestureRecognizer(recognizer)
            recognizers.append(recognizer)
        }
    }

    @objc private func handleSwipe(_ recognizer: UISwipeGestureRecognizer) {
        guard let direction = moveDirection(from: recognizer) else { return }
        onSwipe?(direction)
    }

    private func moveDirection(from recognizer: UISwipeGestureRecognizer) -> MoveDirection? {
        switch recognizer.direction {
        case .up:
            return .up
        case .down:
            return .down
        case .left:
            return .left
        case .right:
            return .right
        default:
            return nil
        }
    }

    private func directionName(for direction: MoveDirection) -> String {
        switch direction {
        case .up:
            return "swipeUp"
        case .down:
            return "swipeDown"
        case .left:
            return "swipeLeft"
        case .right:
            return "swipeRight"
        }
    }
}
