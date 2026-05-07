import Foundation
import GameKit
import UIKit

struct AchievementUnlock {
    let identifier: String
    let title: String
    let unlockedAt: Date
}

struct AchievementProgress {
    let definition: AchievementDefinition
    let unlockedAt: Date?
}

final class GameCenterService: NSObject, GKGameCenterControllerDelegate {
    static let shared = GameCenterService()

    private let leaderboardID = "com.xiaodao.triyan.highscore"
    private let defaults = UserDefaults.standard
    private let unlockedAchievementsKey = "achievements.unlockedIdentifiers"
    private let unlockedAchievementDatesKey = "achievements.unlockedDates"
    private(set) var isAuthenticated = false

    private override init() {}

    func syncHistoricalAchievements(score: Int, maxTile: Int, gamesPlayed: Int) {
        let unlocks = reportAchievements(score: score, maxTile: maxTile, gamesPlayed: gamesPlayed)
        guard !unlocks.isEmpty else { return }
        print("Synced historical achievements: \(unlocks.map(\.identifier).joined(separator: ", "))")
    }

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
            definition.isEarned(score: score, maxTile: maxTile, gamesPlayed: gamesPlayed)
        }

        var unlocked = Set(defaults.stringArray(forKey: unlockedAchievementsKey) ?? [])
        var unlockedDates = migratedUnlockedDateDictionary()
        let unlockedAt = Date()
        let newUnlocks = earned
            .filter { !unlocked.contains($0.identifier) }
            .map { AchievementUnlock(identifier: $0.identifier, title: $0.title, unlockedAt: unlockedAt) }

        guard !newUnlocks.isEmpty else { return [] }

        newUnlocks.forEach { unlock in
            unlocked.insert(unlock.identifier)
            unlockedDates[unlock.identifier] = unlock.unlockedAt.timeIntervalSince1970
        }
        defaults.set(Array(unlocked), forKey: unlockedAchievementsKey)
        defaults.set(unlockedDates, forKey: unlockedAchievementDatesKey)

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

    func progressList() -> [AchievementProgress] {
        let unlockedDates = migratedUnlockedDateDictionary()
        return achievementDefinitions.map { definition in
            let unlockedAt = unlockedDates[definition.identifier].map { Date(timeIntervalSince1970: $0) }
            return AchievementProgress(definition: definition, unlockedAt: unlockedAt)
        }
    }

    func title(for identifier: String) -> String {
        achievementDefinitions.first { $0.identifier == identifier }?.title ?? "未知成就"
    }

    func presentDashboard() {
        presentGameCenter(viewState: .default)
    }

    func presentLeaderboard() {
        presentGameCenter(viewState: .leaderboards, leaderboardIdentifier: leaderboardID)
    }

    func presentAchievements() {
        presentGameCenter(viewState: .achievements)
    }

    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }

    private func presentGameCenter(
        viewState: GKGameCenterViewControllerState,
        leaderboardIdentifier: String? = nil
    ) {
        guard GKLocalPlayer.local.isAuthenticated else {
            authenticateIfNeeded()
            return
        }

        let controller = GKGameCenterViewController()
        controller.gameCenterDelegate = self
        controller.viewState = viewState
        if let leaderboardIdentifier {
            controller.leaderboardIdentifier = leaderboardIdentifier
        }
        Self.topViewController()?.present(controller, animated: true)
    }

    private func unlockedDateDictionary() -> [String: TimeInterval] {
        defaults.dictionary(forKey: unlockedAchievementDatesKey) as? [String: TimeInterval] ?? [:]
    }

    private func migratedUnlockedDateDictionary() -> [String: TimeInterval] {
        let unlocked = Set(defaults.stringArray(forKey: unlockedAchievementsKey) ?? [])
        var dates = unlockedDateDictionary()
        let missingDateIDs = unlocked.filter { dates[$0] == nil }
        guard !missingDateIDs.isEmpty else { return dates }

        let migrationDate = Date().timeIntervalSince1970
        for identifier in missingDateIDs {
            dates[identifier] = migrationDate
        }
        defaults.set(dates, forKey: unlockedAchievementDatesKey)
        return dates
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

struct AchievementDefinition {
    let identifier: String
    let title: String
    let detail: String
    let requiredScore: Int
    let requiredMaxTile: Int
    let requiredGamesPlayed: Int

    func isEarned(score: Int, maxTile: Int, gamesPlayed: Int) -> Bool {
        score >= requiredScore
            && maxTile >= requiredMaxTile
            && gamesPlayed >= requiredGamesPlayed
    }
}

private let achievementDefinitions: [AchievementDefinition] = [
    AchievementDefinition(
        identifier: "com.xiaodao.triyan.achievement.first_game",
        title: "完成首局",
        detail: "完成 1 局游戏",
        requiredScore: 0,
        requiredMaxTile: 0,
        requiredGamesPlayed: 1
    ),
    AchievementDefinition(
        identifier: "com.xiaodao.triyan.achievement.tile_48",
        title: "合成 48",
        detail: "局内合成 48",
        requiredScore: 0,
        requiredMaxTile: 48,
        requiredGamesPlayed: 0
    ),
    AchievementDefinition(
        identifier: "com.xiaodao.triyan.achievement.tile_96",
        title: "合成 96",
        detail: "局内合成 96",
        requiredScore: 0,
        requiredMaxTile: 96,
        requiredGamesPlayed: 0
    ),
    AchievementDefinition(
        identifier: "com.xiaodao.triyan.achievement.tile_192",
        title: "合成 192",
        detail: "局内合成 192",
        requiredScore: 0,
        requiredMaxTile: 192,
        requiredGamesPlayed: 0
    ),
    AchievementDefinition(
        identifier: "com.xiaodao.triyan.achievement.score_100",
        title: "百分上手",
        detail: "单局分数达到 100",
        requiredScore: 100,
        requiredMaxTile: 0,
        requiredGamesPlayed: 0
    ),
    AchievementDefinition(
        identifier: "com.xiaodao.triyan.achievement.score_500",
        title: "五百分突破",
        detail: "单局分数达到 500",
        requiredScore: 500,
        requiredMaxTile: 0,
        requiredGamesPlayed: 0
    ),
    AchievementDefinition(
        identifier: "com.xiaodao.triyan.achievement.score_1000",
        title: "千分局",
        detail: "单局分数达到 1000",
        requiredScore: 1000,
        requiredMaxTile: 0,
        requiredGamesPlayed: 0
    ),
    AchievementDefinition(
        identifier: "com.xiaodao.triyan.achievement.games_10",
        title: "十局练习",
        detail: "累计完成 10 局",
        requiredScore: 0,
        requiredMaxTile: 0,
        requiredGamesPlayed: 10
    )
]
