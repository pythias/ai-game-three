import Foundation
import GameKit
import UIKit

final class GameCenterService {
    static let shared = GameCenterService()

    private let leaderboardID = "com.xiaodao.triyan.highscore"
    private(set) var isAuthenticated = false

    private init() {}

    func authenticateIfNeeded() {
        let localPlayer = GKLocalPlayer.local
        localPlayer.authenticateHandler = { [weak self] viewController, error in
            if let error {
                print("Game Center authentication error: \(error.localizedDescription)")
            }

            self?.isAuthenticated = localPlayer.isAuthenticated

            guard let viewController else { return }
            DispatchQueue.main.async {
                Self.topViewController()?.present(viewController, animated: true)
            }
        }
    }

    func submit(score: Int) {
        guard isAuthenticated else { return }

        GKLeaderboard.submitScore(
            score,
            context: 0,
            player: GKLocalPlayer.local,
            leaderboardIDs: [leaderboardID]
        ) { error in
            if let error {
                print("Game Center score submit error: \(error.localizedDescription)")
            }
        }
    }

    private static func topViewController(
        from root: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
    ) -> UIViewController? {
        if let navigationController = root as? UINavigationController {
            return topViewController(from: navigationController.visibleViewController)
        }
        if let tabBarController = root as? UITabBarController {
            return topViewController(from: tabBarController.selectedViewController)
        }
        if let presented = root?.presentedViewController {
            return topViewController(from: presented)
        }
        return root
    }
}
