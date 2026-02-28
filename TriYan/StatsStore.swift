import Foundation

struct StatsSnapshot {
    let topScores: [Int]
    let gamesPlayed: Int
    let lifetimeHistogram: [(value: Int, count: Int)]
    let maxTileEver: Int
}

final class StatsStore {
    static let shared = StatsStore()

    private let defaults = UserDefaults.standard
    private let topScoresKey = "stats.topScores"
    private let gamesPlayedKey = "stats.gamesPlayed"
    private let lifetimeHistogramKey = "stats.lifetimeHistogram"

    private init() {}

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
    }

    func snapshot() -> StatsSnapshot {
        let topScores = defaults.array(forKey: topScoresKey) as? [Int] ?? []
        let gamesPlayed = defaults.integer(forKey: gamesPlayedKey)
        let histogramDict = loadHistogramDictionary()
        let histogram = histogramDict
            .map { (value: $0.key, count: $0.value) }
            .sorted { $0.value < $1.value }
        let maxTileEver = histogram.last?.value ?? 0

        return StatsSnapshot(
            topScores: topScores,
            gamesPlayed: gamesPlayed,
            lifetimeHistogram: histogram,
            maxTileEver: maxTileEver
        )
    }

    func lifetimeCount(for value: Int) -> Int {
        loadHistogramDictionary()[value] ?? 0
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
}
