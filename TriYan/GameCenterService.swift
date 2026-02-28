import Foundation
import GameKit
import UIKit

enum GameAchievementKey: String, CaseIterable {
    case score100
    case score500
    case score1500
    case score3000
    case maxTile24
    case maxTile48
    case maxTile96
    case gamesPlayed10
    case gamesPlayed50
    case tile3Count100
}

struct LeaderboardEntry {
    let rank: Int
    let playerName: String
    let score: Int
}

final class GameCenterService {
    static let shared = GameCenterService()

    // Replace these IDs with the real App Store Connect identifiers later.
    let leaderboardID = "com.xiaodao.triyan.leaderboard.total_score"
    private let achievementIDs: [GameAchievementKey: String] = [
        .score100: "com.xiaodao.triyan.achievement.score100",
        .score500: "com.xiaodao.triyan.achievement.score500",
        .score1500: "com.xiaodao.triyan.achievement.score1500",
        .score3000: "com.xiaodao.triyan.achievement.score3000",
        .maxTile24: "com.xiaodao.triyan.achievement.max_tile24",
        .maxTile48: "com.xiaodao.triyan.achievement.max_tile48",
        .maxTile96: "com.xiaodao.triyan.achievement.max_tile96",
        .gamesPlayed10: "com.xiaodao.triyan.achievement.games_played10",
        .gamesPlayed50: "com.xiaodao.triyan.achievement.games_played50",
        .tile3Count100: "com.xiaodao.triyan.achievement.tile3_count100"
    ]

    private init() {}

    var isAuthenticated: Bool {
        GKLocalPlayer.local.isAuthenticated
    }

    func authenticate(presentingViewController: UIViewController?) {
        GKLocalPlayer.local.authenticateHandler = { viewController, _ in
            if let viewController {
                presentingViewController?.present(viewController, animated: true)
            }
        }
    }

    func submitScore(_ score: Int) {
        guard isAuthenticated else { return }
        let value = Int64(score)
        GKLeaderboard.submitScore(Int(value), context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboardID]) { _ in
            // Keep gameplay unaffected if reporting fails.
        }
    }

    func reportAchievementProgress(_ progressByKey: [GameAchievementKey: Double]) {
        guard isAuthenticated, !progressByKey.isEmpty else { return }

        let achievements: [GKAchievement] = progressByKey.compactMap { item in
            guard let achievementID = achievementIDs[item.key] else { return nil }
            let achievement = GKAchievement(identifier: achievementID)
            achievement.percentComplete = min(max(item.value, 0.0), 100.0)
            achievement.showsCompletionBanner = true
            return achievement
        }

        guard !achievements.isEmpty else { return }
        GKAchievement.report(achievements) { _ in
            // Keep gameplay unaffected if reporting fails.
        }
    }

    func loadGlobalLeaderboardTop(limit: Int, completion: @escaping ([LeaderboardEntry]) -> Void) {
        guard isAuthenticated else {
            completion([])
            return
        }

        GKLeaderboard.loadLeaderboards(IDs: [leaderboardID]) { leaderboards, _ in
            guard
                let leaderboard = leaderboards?.first,
                limit > 0
            else {
                completion([])
                return
            }

            leaderboard.loadEntries(for: .global, timeScope: .allTime, range: NSRange(location: 1, length: limit)) { _, entries, _, _ in
                let result = (entries ?? []).map { entry in
                    LeaderboardEntry(
                        rank: entry.rank,
                        playerName: entry.player.displayName,
                        score: Int(entry.score)
                    )
                }
                completion(result)
            }
        }
    }
}
