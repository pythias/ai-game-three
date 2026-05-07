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

    private let highScoreLeaderboardID = "com.xiaodao.triyan.highscore"
    private let tileLeaderboardPrefix = "com.xiaodao.triyan.tile"
    private let leaderboardTileValues = [3, 6, 12, 24, 48, 96, 192, 384, 768, 1536, 3072, 6144, 12288, 24576]
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
            leaderboardIDs: [highScoreLeaderboardID]
        ) { error in
            if let error {
                print("Game Center score submit error: \(error.localizedDescription)")
            }
        }
    }

    func submitGameResult(score: Int, lifetimeTileCounts: [(value: Int, count: Int)]) {
        submit(score: score)

        guard isAuthenticated else { return }
        let countsByValue = Dictionary(uniqueKeysWithValues: lifetimeTileCounts)
        for value in leaderboardTileValues {
            let count = countsByValue[value] ?? 0
            guard count > 0 else { continue }
            GKLeaderboard.submitScore(
                count,
                context: Int(value),
                player: GKLocalPlayer.local,
                leaderboardIDs: [tileLeaderboardID(for: value)]
            ) { error in
                if let error {
                    print("Game Center tile \(value) leaderboard submit error: \(error.localizedDescription)")
                }
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
        presentGameCenter(viewState: .leaderboards, leaderboardIdentifier: highScoreLeaderboardID)
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

    private func tileLeaderboardID(for value: Int) -> String {
        "\(tileLeaderboardPrefix).\(value).count"
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

    init(
        identifier: String,
        title: String,
        detail: String,
        requiredScore: Int = 0,
        requiredMaxTile: Int = 0,
        requiredGamesPlayed: Int = 0
    ) {
        self.identifier = identifier
        self.title = title
        self.detail = detail
        self.requiredScore = requiredScore
        self.requiredMaxTile = requiredMaxTile
        self.requiredGamesPlayed = requiredGamesPlayed
    }

    func isEarned(score: Int, maxTile: Int, gamesPlayed: Int) -> Bool {
        score >= requiredScore
            && maxTile >= requiredMaxTile
            && gamesPlayed >= requiredGamesPlayed
    }
}

private let achievementDefinitions: [AchievementDefinition] = {
    let gameAchievements = [
        AchievementDefinition(
            identifier: "com.xiaodao.triyan.achievement.first_game",
            title: "完成首局",
            detail: "完成 1 局游戏",
            requiredGamesPlayed: 1
        ),
        AchievementDefinition(
            identifier: "com.xiaodao.triyan.achievement.games_10",
            title: "十局练习",
            detail: "累计完成 10 局",
            requiredGamesPlayed: 10
        ),
        AchievementDefinition(
            identifier: "com.xiaodao.triyan.achievement.games_25",
            title: "稳定练习",
            detail: "累计完成 25 局",
            requiredGamesPlayed: 25
        ),
        AchievementDefinition(
            identifier: "com.xiaodao.triyan.achievement.games_50",
            title: "五十局突破",
            detail: "累计完成 50 局",
            requiredGamesPlayed: 50
        ),
        AchievementDefinition(
            identifier: "com.xiaodao.triyan.achievement.games_100",
            title: "百局达人",
            detail: "累计完成 100 局",
            requiredGamesPlayed: 100
        )
    ]

    let scoreAchievements: [(score: Int, title: String)] = [
        (100, "百分上手"),
        (500, "五百分突破"),
        (1_000, "千分局"),
        (2_000, "两千分"),
        (5_000, "五千分"),
        (10_000, "万分挑战"),
        (20_000, "两万分大师"),
        (50_000, "五万分传说")
    ]

    let tileAchievements: [(tile: Int, title: String)] = [
        (48, "合成 48"),
        (96, "合成 96"),
        (192, "合成 192"),
        (384, "合成 384"),
        (768, "合成 768"),
        (1_536, "合成 1536"),
        (3_072, "合成 3072"),
        (6_144, "合成 6144"),
        (12_288, "合成 12288"),
        (24_576, "合成 24576")
    ]

    return gameAchievements
        + scoreAchievements.map { item in
            AchievementDefinition(
                identifier: "com.xiaodao.triyan.achievement.score_\(item.score)",
                title: item.title,
                detail: "单局分数达到 \(item.score)",
                requiredScore: item.score
            )
        }
        + tileAchievements.map { item in
            AchievementDefinition(
                identifier: "com.xiaodao.triyan.achievement.tile_\(item.tile)",
                title: item.title,
                detail: "局内合成 \(item.tile)",
                requiredMaxTile: item.tile
            )
        }
}()
