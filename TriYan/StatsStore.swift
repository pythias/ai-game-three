import Foundation

struct GameRecord: Codable, Equatable {
    let playedAt: Date
    let score: Int
    let maxTile: Int
}

struct StatsSnapshot {
    let topScores: [Int]
    let gamesPlayed: Int
    let lifetimeHistogram: [(value: Int, count: Int)]
    let maxTileEver: Int
    let bestScore: Int
    let recentGames: [GameRecord]
}

final class StatsStore {
    static let shared = StatsStore()

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private let topScoresKey = "stats.topScores"
    private let gamesPlayedKey = "stats.gamesPlayed"
    private let lifetimeHistogramKey = "stats.lifetimeHistogram"
    private let recentGamesKey = "stats.recentGames"
    private let recentGameLimit = 20

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func recordGame(resultScore: Int, histogram: [(value: Int, count: Int)]) {
        var topScores = defaults.array(forKey: topScoresKey) as? [Int] ?? []
        topScores.append(resultScore)
        topScores.sort(by: >)
        if topScores.count > 10 {
            topScores = Array(topScores.prefix(10))
        }
        defaults.set(topScores, forKey: topScoresKey)

        let gamesPlayed = defaults.integer(forKey: gamesPlayedKey) + 1
        defaults.set(gamesPlayed, forKey: gamesPlayedKey)

        var mergedHistogram = loadHistogramDictionary()
        for item in histogram where item.count > 0 {
            mergedHistogram[item.value, default: 0] += item.count
        }
        defaults.set(serializeHistogram(mergedHistogram), forKey: lifetimeHistogramKey)

        let record = GameRecord(
            playedAt: Date(),
            score: resultScore,
            maxTile: histogram.last(where: { $0.count > 0 })?.value ?? 0
        )
        var recentGames = loadRecentGames()
        recentGames.insert(record, at: 0)
        if recentGames.count > recentGameLimit {
            recentGames = Array(recentGames.prefix(recentGameLimit))
        }
        persistRecentGames(recentGames)
    }

    func snapshot() -> StatsSnapshot {
        let topScores = defaults.array(forKey: topScoresKey) as? [Int] ?? []
        let gamesPlayed = defaults.integer(forKey: gamesPlayedKey)
        let histogramDict = loadHistogramDictionary()
        let histogram = histogramDict
            .map { (value: $0.key, count: $0.value) }
            .sorted { $0.value < $1.value }
        let maxTileEver = histogram.last?.value ?? 0
        let recentGames = loadRecentGames()

        return StatsSnapshot(
            topScores: topScores,
            gamesPlayed: gamesPlayed,
            lifetimeHistogram: histogram,
            maxTileEver: maxTileEver,
            bestScore: topScores.first ?? 0,
            recentGames: recentGames
        )
    }

    func lifetimeCount(for value: Int) -> Int {
        loadHistogramDictionary()[value] ?? 0
    }

    func bestScore() -> Int {
        snapshot().bestScore
    }

    private func loadHistogramDictionary() -> [Int: Int] {
        let raw = defaults.dictionary(forKey: lifetimeHistogramKey) as? [String: Int] ?? [:]
        var result: [Int: Int] = [:]
        for (key, count) in raw {
            guard let value = Int(key) else { continue }
            result[value] = count
        }
        return result
    }

    private func serializeHistogram(_ histogram: [Int: Int]) -> [String: Int] {
        var result: [String: Int] = [:]
        for (value, count) in histogram {
            result[String(value)] = count
        }
        return result
    }

    private func loadRecentGames() -> [GameRecord] {
        guard let data = defaults.data(forKey: recentGamesKey),
              let games = try? decoder.decode([GameRecord].self, from: data) else {
            return []
        }
        return games
    }

    private func persistRecentGames(_ games: [GameRecord]) {
        guard let data = try? encoder.encode(games) else { return }
        defaults.set(data, forKey: recentGamesKey)
    }
}
