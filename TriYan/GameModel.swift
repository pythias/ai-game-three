import Foundation

enum MoveDirection: CaseIterable {
    case east
    case west
    case northeast
    case southwest
    case northwest
    case southeast

    var axialDelta: (q: Int, r: Int) {
        switch self {
        case .east: return (1, 0)
        case .west: return (-1, 0)
        case .northeast: return (1, -1)
        case .southwest: return (-1, 1)
        case .northwest: return (0, -1)
        case .southeast: return (0, 1)
        }
    }
}

struct GridPosition: Hashable {
    /// Axial r coordinate.
    let row: Int
    /// Axial q coordinate.
    let col: Int

    var q: Int { col }
    var r: Int { row }
    var s: Int { -q - r }
}

struct TileMovement {
    let from: GridPosition
    let to: GridPosition
    let value: Int
    let consumedInMerge: Bool
}

struct MergeEvent {
    let at: GridPosition
    let resultValue: Int
}

struct MoveResult {
    let didMove: Bool
    let movements: [TileMovement]
    let merges: [MergeEvent]
    let spawnCandidates: [GridPosition]
}

final class GameModel {
    static let boardRadius = 2
    static let boardCellCount = 19

    static let visualPositions: [GridPosition] = {
        var positions: [GridPosition] = []
        for r in -boardRadius...boardRadius {
            let minQ = max(-boardRadius, -r - boardRadius)
            let maxQ = min(boardRadius, -r + boardRadius)
            for q in minQ...maxQ {
                positions.append(GridPosition(row: r, col: q))
            }
        }
        return positions
    }()

    private static let validPositions = Set(visualPositions)

    private(set) var score = 0
    private var cells: [GridPosition: Tile] = [:]

    var board: [Tile?] {
        Self.visualPositions.map { cells[$0] }
    }

    var emptyPositions: [GridPosition] {
        Self.visualPositions.filter { cells[$0] == nil }
    }

    var isGameOver: Bool {
        if !emptyPositions.isEmpty {
            return false
        }
        return !hasAvailableMerge()
    }

    var maxTileValue: Int {
        cells.values.map(\.value).max() ?? 0
    }

    var boardSnapshot: [Int] {
        Self.visualPositions.map { cells[$0]?.value ?? 0 }
    }

    func threesStyleResult() -> Int {
        let maxValue = cells.values.map(\.value).max() ?? 0
        guard maxValue >= 3 else { return 0 }

        var result = 0
        var value = 3

        while value <= maxValue {
            let count = cells.values.reduce(0) { partial, tile in
                partial + (tile.value == value ? 1 : 0)
            }
            if count > 0 {
                result += count * scoreForTileValue(value)
            }
            value *= 2
        }

        return result
    }

    func tileHistogramFromThree() -> [(value: Int, count: Int)] {
        let maxValue = cells.values.map(\.value).max() ?? 0
        guard maxValue >= 3 else { return [] }

        var histogram: [(value: Int, count: Int)] = []
        var value = 3
        while value <= maxValue {
            let count = cells.values.reduce(0) { partial, tile in
                partial + (tile.value == value ? 1 : 0)
            }
            histogram.append((value: value, count: count))
            value *= 2
        }
        return histogram
    }

    func scoreForTileValue(_ value: Int) -> Int {
        guard value >= 3 else { return 0 }
        var level = 1
        var current = 3
        while current < value {
            current *= 2
            level += 1
        }
        return current == value ? threesWeight(level: level) : 0
    }

    func reset() {
        score = 0
        cells.removeAll(keepingCapacity: true)
    }

    func restore(cells: [GridPosition: Tile], score: Int) {
        self.cells = cells
        self.score = score
    }

    func snapshot() -> [GridPosition: Tile] {
        cells
    }

    func tile(at position: GridPosition) -> Tile? {
        guard isValid(position) else { return nil }
        return cells[position]
    }

    @discardableResult
    func place(_ newTile: Tile, at position: GridPosition) -> Bool {
        guard isValid(position), cells[position] == nil else { return false }
        cells[position] = newTile
        return true
    }

    func move(_ direction: MoveDirection, commit: Bool = true) -> MoveResult {
        var working = cells
        var movements: [TileMovement] = []
        var merges: [MergeEvent] = []
        var didMove = false
        var scoreDelta = 0
        var mergedDestinations: Set<GridPosition> = []

        for source in traversalOrder(for: direction) {
            guard let sourceTile = working[source] else { continue }
            let destination = Self.neighbor(from: source, direction: direction)
            guard isValid(destination) else { continue }

            if let targetTile = working[destination] {
                guard !mergedDestinations.contains(destination),
                      let mergedTile = Tile.mergedValue(sourceTile, targetTile) else { continue }
                working[source] = nil
                working[destination] = mergedTile
                movements.append(TileMovement(from: source, to: destination, value: sourceTile.value, consumedInMerge: true))
                movements.append(TileMovement(from: destination, to: destination, value: targetTile.value, consumedInMerge: true))
                merges.append(MergeEvent(at: destination, resultValue: mergedTile.value))
                mergedDestinations.insert(destination)
                scoreDelta += mergedTile.value
                didMove = true
            } else {
                working[source] = nil
                working[destination] = sourceTile
                movements.append(TileMovement(from: source, to: destination, value: sourceTile.value, consumedInMerge: false))
                didMove = true
            }
        }

        if didMove && commit {
            cells = working
            score += scoreDelta
        }

        return MoveResult(
            didMove: didMove,
            movements: didMove ? movements : [],
            merges: didMove ? merges : [],
            spawnCandidates: didMove ? spawnCandidates(for: direction, board: working) : []
        )
    }

    static func isValid(_ position: GridPosition) -> Bool {
        validPositions.contains(position)
    }

    static func neighbor(from position: GridPosition, direction: MoveDirection) -> GridPosition {
        let delta = direction.axialDelta
        return GridPosition(row: position.r + delta.r, col: position.q + delta.q)
    }

    private func isValid(_ position: GridPosition) -> Bool {
        Self.isValid(position)
    }

    private func traversalOrder(for direction: MoveDirection) -> [GridPosition] {
        let delta = direction.axialDelta
        return Self.visualPositions.sorted { lhs, rhs in
            let lhsProjection = lhs.q * delta.q + lhs.r * delta.r
            let rhsProjection = rhs.q * delta.q + rhs.r * delta.r
            if lhsProjection != rhsProjection {
                return lhsProjection > rhsProjection
            }
            if lhs.r != rhs.r {
                return lhs.r < rhs.r
            }
            return lhs.q < rhs.q
        }
    }

    private func spawnCandidates(for direction: MoveDirection, board: [GridPosition: Tile]) -> [GridPosition] {
        let delta = direction.axialDelta
        let oppositeEdge = Self.visualPositions.filter { position in
            let behind = GridPosition(row: position.r - delta.r, col: position.q - delta.q)
            return !isValid(behind) && board[position] == nil
        }

        if !oppositeEdge.isEmpty {
            return oppositeEdge
        }

        return Self.visualPositions.filter { board[$0] == nil }
    }

    private func hasAvailableMerge() -> Bool {
        for position in Self.visualPositions {
            guard let currentTile = tile(at: position) else { continue }
            for direction in MoveDirection.allCases {
                let neighbor = Self.neighbor(from: position, direction: direction)
                if let neighborTile = tile(at: neighbor), Tile.canMerge(currentTile, neighborTile) {
                    return true
                }
            }
        }
        return false
    }

    private func threesWeight(level: Int) -> Int {
        guard level > 0 else { return 0 }
        return Int(pow(3.0, Double(level)))
    }
}
