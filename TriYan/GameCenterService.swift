import Foundation
import GameKit
import UIKit

struct AchievementUnlock {
    let identifier: String
    let title: String
}

final class GameCenterService {
    static let shared = GameCenterService()

    private let leaderboardID = "com.xiaodao.triyan.highscore"
    private let defaults = UserDefaults.standard
    private let unlockedAchievementsKey = "achievements.unlockedIdentifiers"
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

    func reportAchievements(score: Int, maxTile: Int, gamesPlayed: Int) -> [AchievementUnlock] {
        let earned = achievementDefinitions.filter { definition in
            score >= definition.requiredScore
                && maxTile >= definition.requiredMaxTile
                && gamesPlayed >= definition.requiredGamesPlayed
        }

        var unlocked = Set(defaults.stringArray(forKey: unlockedAchievementsKey) ?? [])
        let newUnlocks = earned
            .filter { !unlocked.contains($0.identifier) }
            .map { AchievementUnlock(identifier: $0.identifier, title: $0.title) }

        guard !newUnlocks.isEmpty else { return [] }

        newUnlocks.forEach { unlocked.insert($0.identifier) }
        defaults.set(Array(unlocked), forKey: unlockedAchievementsKey)

        guard isAuthenticated else { return newUnlocks }

        let achievements = newUnlocks.map { unlock in
            let achievement = GKAchievement(identifier: unlock.identifier)
            achievement.percentComplete = 100
            achievement.showsCompletionBanner = false
            return achievement
        }

        GKAchievement.report(achievements) { error in
            if let error {
                print("Game Center achievement submit error: \(error.localizedDescription)")
            }
        }

        return newUnlocks
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

private struct AchievementDefinition {
    let identifier: String
    let title: String
    let requiredScore: Int
    let requiredMaxTile: Int
    let requiredGamesPlayed: Int
}

private let achievementDefinitions: [AchievementDefinition] = [
    AchievementDefinition(
        identifier: "com.xiaodao.triyan.achievement.first_game",
        title: "完成首局",
        requiredScore: 0,
        requiredMaxTile: 0,
        requiredGamesPlayed: 1
    ),
    AchievementDefinition(
        identifier: "com.xiaodao.triyan.achievement.tile_48",
        title: "合成 48",
        requiredScore: 0,
        requiredMaxTile: 48,
        requiredGamesPlayed: 0
    ),
    AchievementDefinition(
        identifier: "com.xiaodao.triyan.achievement.tile_96",
        title: "合成 96",
        requiredScore: 0,
        requiredMaxTile: 96,
        requiredGamesPlayed: 0
    ),
    AchievementDefinition(
        identifier: "com.xiaodao.triyan.achievement.tile_192",
        title: "合成 192",
        requiredScore: 0,
        requiredMaxTile: 192,
        requiredGamesPlayed: 0
    ),
    AchievementDefinition(
        identifier: "com.xiaodao.triyan.achievement.score_100",
        title: "百分上手",
        requiredScore: 100,
        requiredMaxTile: 0,
        requiredGamesPlayed: 0
    ),
    AchievementDefinition(
        identifier: "com.xiaodao.triyan.achievement.score_500",
        title: "五百分突破",
        requiredScore: 500,
        requiredMaxTile: 0,
        requiredGamesPlayed: 0
    ),
    AchievementDefinition(
        identifier: "com.xiaodao.triyan.achievement.score_1000",
        title: "千分局",
        requiredScore: 1000,
        requiredMaxTile: 0,
        requiredGamesPlayed: 0
    ),
    AchievementDefinition(
        identifier: "com.xiaodao.triyan.achievement.games_10",
        title: "十局练习",
        requiredScore: 0,
        requiredMaxTile: 0,
        requiredGamesPlayed: 10
    )
]
