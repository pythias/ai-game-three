import Foundation

final class Spawner {
    private(set) var previewTile: Tile
    private var seededGenerator: SeededRandomGenerator?

    init() {
        previewTile = Tile(1)
    }

    func reset(for board: [Tile?]) {
        previewTile = rollTile(for: board)
    }

    func takePreviewTile() -> Tile {
        previewTile
    }

    func refreshPreview(for board: [Tile?]) {
        previewTile = rollTile(for: board)
    }

    func forcePreview(value: Int) {
        previewTile = Tile(value)
    }

    func configureNormalMode() {
        seededGenerator = nil
    }

    func configureDailyMode(seed: UInt64) {
        seededGenerator = SeededRandomGenerator(seed: seed)
    }

    var deterministicState: UInt64? {
        get { seededGenerator?.stateValue }
        set {
            if let newValue {
                seededGenerator = SeededRandomGenerator(rawState: newValue)
            } else {
                seededGenerator = nil
            }
        }
    }

    func choosePosition(from positions: [GridPosition]) -> GridPosition? {
        guard !positions.isEmpty else { return nil }
        guard var generator = seededGenerator else {
            return positions.randomElement()
        }
        let index = Int.random(in: 0..<positions.count, using: &generator)
        seededGenerator = generator
        return positions[index]
    }

    /// Roll a new tile to spawn.
    /// The hex board has more movement directions than a square board, so the
    /// generator adds pressure as the board develops instead of changing moves.
    private func rollTile(for board: [Tile?]) -> Tile {
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

        let roll = nextDouble()

        let canSpawnHigh = emptyCount >= 4 && !highValues.isEmpty

        if roll < basicSpawnChance || !hasLowTiles || !canSpawnHigh {
            return rollBasicTile(for: board, tileCounts: tileCounts, emptyCount: emptyCount)
        } else {
            return rollHighTile(values: highValues, counts: tileCounts)
        }
    }

    /// Roll a basic tile (1, 2, or 3)
    private func rollBasicTile(for board: [Tile?], tileCounts: [Int: Int], emptyCount: Int) -> Tile {
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

        let roll = nextInt(upperBound: total)
        if roll < w1 {
            return Tile(1)
        }
        if roll < w1 + w2 {
            return Tile(2)
        }
        return Tile(3)
    }

    /// Roll a high value tile (6, 12, 24, etc.)
    private func rollHighTile(values: [Int], counts: [Int: Int]) -> Tile {
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
        var roll = nextInt(upperBound: totalWeight)

        for item in weightedValues {
            roll -= item.weight
            if roll < 0 {
                return Tile(item.value)
            }
        }

        // Fallback
        return Tile(weightedValues.first?.value ?? 6)
    }

    private func nextInt(upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        guard var generator = seededGenerator else {
            return Int.random(in: 0..<upperBound)
        }
        let value = Int.random(in: 0..<upperBound, using: &generator)
        seededGenerator = generator
        return value
    }

    private func nextDouble() -> Double {
        guard var generator = seededGenerator else {
            return Double.random(in: 0...1)
        }
        let value = Double.random(in: 0...1, using: &generator)
        seededGenerator = generator
        return value
    }
}

private struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    init(rawState: UInt64) {
        state = rawState == 0 ? 0x9E3779B97F4A7C15 : rawState
    }

    var stateValue: UInt64 {
        state
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
