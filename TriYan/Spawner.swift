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

    /// Roll a new tile to spawn
    /// Strategy:
    /// - 70% chance: spawn 1, 2, or 3 (basic tiles)
    /// - 30% chance: spawn a higher tile that exists on board
    private static func rollTile(for board: [Tile?]) -> Tile {
        // Count tiles on board
        var tileCounts: [Int: Int] = [:]  // value -> count
        var emptyCount = 0

        for tile in board {
            guard let tile else {
                emptyCount += 1
                continue
            }
            tileCounts[tile.value, default: 0] += 1
        }

        // Get all unique tile values on board (excluding 1,2,3 for diversity spawns)
        let highValues = tileCounts.keys.filter { $0 >= 6 }.sorted()
        let hasLowTiles = tileCounts.keys.contains(where: { $0 <= 3 })

        // Determine spawn type: basic (1,2,3) or high value
        // Reduce high value chance when board is getting full
        let boardCapacity = max(board.count, 1)
        let boardFullness = 1.0 - (Double(emptyCount) / Double(boardCapacity))  // 0 = empty, 1 = full
        let basicSpawnChance = 0.85 + (boardFullness * 0.15)  // 85-100% basic tiles

        let roll = Double.random(in: 0...1)

        // Don't spawn high values when board is nearly full (harder to place)
        let canSpawnHigh = emptyCount >= 6 && highValues.count > 0

        if roll < basicSpawnChance || !hasLowTiles || !canSpawnHigh {
            // Spawn basic tile (1, 2, or 3)
            return rollBasicTile(for: board, tileCounts: tileCounts, emptyCount: emptyCount)
        } else if !highValues.isEmpty {
            // Spawn a high value tile that exists on board
            return rollHighTile(values: highValues, counts: tileCounts)
        } else {
            // Fallback to basic
            return rollBasicTile(for: board, tileCounts: tileCounts, emptyCount: emptyCount)
        }
    }

    /// Roll a basic tile (1, 2, or 3)
    private static func rollBasicTile(for board: [Tile?], tileCounts: [Int: Int], emptyCount: Int) -> Tile {
        let oneCount = tileCounts[1] ?? 0
        let twoCount = tileCounts[2] ?? 0
        let threeCount = tileCounts[3] ?? 0

        var w1 = 3  // weight for 1
        var w2 = 3  // weight for 2
        var w3 = 2  // weight for 3

        // Balance weights based on board state
        let imbalance = twoCount - oneCount
        if imbalance >= 2 {
            w1 += imbalance * 2
            w2 = max(1, w2 - imbalance)
        } else if imbalance <= -2 {
            let reversed = -imbalance
            w2 += reversed * 2
            w1 = max(1, w1 - reversed)
        }

        // Ensure we always have some of each
        if oneCount == 0 {
            w1 += 4
        }
        if twoCount == 0 {
            w2 += 4
        }

        // Adjust based on empty space (more pressure when crowded)
        if emptyCount <= 4 {
            w1 += 2
            w2 += 1
            w3 = max(1, w3 - 1)
        }

        if emptyCount <= 2 {
            w3 = 0  // No 3 when very crowded
        }

        // Encourage 3 when both 1 and 2 exist
        if threeCount == 0 && oneCount > 0 && twoCount > 0 && emptyCount >= 6 {
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
        // Weight higher values less (they're harder to place)
        // But also consider how many of each exist
        var weightedValues: [(value: Int, weight: Int)] = []

        for v in values {
            let count = counts[v] ?? 1
            // Lower weight for higher values, but more weight if few exist
            let weight: Int
            switch v {
            case 6: weight = 8
            case 12: weight = 6
            case 24: weight = 4
            case 48: weight = 3
            case 96: weight = 2
            default: weight = 1
            }
            // Adjust by existing count (more likely to spawn if rare)
            let adjustedWeight = weight * max(1, 3 - count)
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
