import Foundation

final class Spawner {
    private(set) var previewTile: Tile

    init() {
        previewTile = Tile(1)
    }

    func reset(for board: [Tile?]) {
        previewTile = Spawner.rollTile(for: board)
    }

    func takePreviewTile() -> Tile {
        previewTile
    }

    func refreshPreview(for board: [Tile?]) {
        previewTile = Spawner.rollTile(for: board)
    }

    func forcePreview(value: Int) {
        previewTile = Tile(value)
    }

    /// Roll a new tile to spawn.
    /// The hex board has more movement directions than a square board, so the
    /// generator adds pressure as the board develops instead of changing moves.
    private static func rollTile(for board: [Tile?]) -> Tile {
        var tileCounts: [Int: Int] = [:]  // value -> count
        var emptyCount = 0

        for tile in board {
            guard let tile else {
                emptyCount += 1
                continue
            }
            tileCounts[tile.value, default: 0] += 1
        }

        let maxTile = tileCounts.keys.max() ?? 0
        let highValues = tileCounts.keys.filter { $0 >= 6 && $0 <= max(6, maxTile / 2) }.sorted()
        let hasLowTiles = tileCounts.keys.contains(where: { $0 <= 3 })

        let boardCapacity = max(board.count, 1)
        let boardFullness = 1.0 - (Double(emptyCount) / Double(boardCapacity))
        let progressPressure = min(0.28, Double(maxTile) / 1536.0 * 0.28)
        let crowdMercy = boardFullness * 0.16
        let basicSpawnChance = min(0.96, max(0.62, 0.82 - progressPressure + crowdMercy))

        let roll = Double.random(in: 0...1)

        let canSpawnHigh = emptyCount >= 4 && !highValues.isEmpty

        if roll < basicSpawnChance || !hasLowTiles || !canSpawnHigh {
            return rollBasicTile(for: board, tileCounts: tileCounts, emptyCount: emptyCount)
        } else {
            return rollHighTile(values: highValues, counts: tileCounts)
        }
    }

    /// Roll a basic tile (1, 2, or 3)
    private static func rollBasicTile(for board: [Tile?], tileCounts: [Int: Int], emptyCount: Int) -> Tile {
        let oneCount = tileCounts[1] ?? 0
        let twoCount = tileCounts[2] ?? 0
        let threeCount = tileCounts[3] ?? 0

        var w1 = 4  // weight for 1
        var w2 = 4  // weight for 2
        var w3 = 3  // weight for 3

        let imbalance = twoCount - oneCount
        if imbalance >= 2 {
            w1 += imbalance
            w2 = max(2, w2 - imbalance / 2)
        } else if imbalance <= -2 {
            let reversed = -imbalance
            w2 += reversed
            w1 = max(2, w1 - reversed / 2)
        }

        if oneCount == 0 {
            w1 += 3
        }
        if twoCount == 0 {
            w2 += 3
        }

        if emptyCount <= 4 {
            w1 += 2
            w2 += 1
            w3 = max(1, w3 - 1)
        }

        if emptyCount <= 2 {
            w3 = 0  // No 3 when very crowded
        }

        if threeCount == 0 && oneCount > 0 && twoCount > 0 && emptyCount >= 5 {
            w3 += 1
        }

        let total = w1 + w2 + max(0, w3)
        guard total > 0 else { return Tile(1) }

        let roll = Int.random(in: 0..<total)
        if roll < w1 {
            return Tile(1)
        }
        if roll < w1 + w2 {
            return Tile(2)
        }
        return Tile(3)
    }

    /// Roll a high value tile (6, 12, 24, etc.)
    private static func rollHighTile(values: [Int], counts: [Int: Int]) -> Tile {
        var weightedValues: [(value: Int, weight: Int)] = []

        for v in values {
            let count = counts[v] ?? 1
            let weight: Int
            switch v {
            case 6: weight = 10
            case 12: weight = 8
            case 24: weight = 6
            case 48: weight = 3
            case 96: weight = 2
            default: weight = 1
            }
            let adjustedWeight = weight * max(1, 4 - count)
            weightedValues.append((v, adjustedWeight))
        }

        let totalWeight = weightedValues.reduce(0) { $0 + $1.weight }
        var roll = Int.random(in: 0..<totalWeight)

        for item in weightedValues {
            roll -= item.weight
            if roll < 0 {
                return Tile(item.value)
            }
        }

        // Fallback
        return Tile(weightedValues.first?.value ?? 6)
    }
}
