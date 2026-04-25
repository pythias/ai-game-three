import Foundation

enum MoveDirection {
    case up
    case down
    case left
    case right
}

struct GridPosition: Hashable {
    let row: Int
    let col: Int
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
    static let boardSize = 4

    private(set) var score = 0
    private var cells: [Tile?] = Array(repeating: nil, count: boardSize * boardSize)

    var board: [Tile?] {
        cells
    }

    var emptyPositions: [GridPosition] {
        allPositions().filter { tile(at: $0) == nil }
    }

    var isGameOver: Bool {
        if !emptyPositions.isEmpty {
            return false
        }
        return !hasAvailableMerge()
    }

    func threesStyleResult() -> Int {
        let maxValue = cells.compactMap { $0?.value }.max() ?? 0
        guard maxValue >= 3 else { return 0 }

        var result = 0
        var value = 3

        while value <= maxValue {
            let count = cells.reduce(0) { partial, tile in
                partial + ((tile?.value == value) ? 1 : 0)
            }
            if count > 0 {
                result += count * scoreForTileValue(value)
            }
            value *= 2
        }

        return result
    }

    func tileHistogramFromThree() -> [(value: Int, count: Int)] {
        let maxValue = cells.compactMap { $0?.value }.max() ?? 0
        guard maxValue >= 3 else { return [] }

        var histogram: [(value: Int, count: Int)] = []
        var value = 3
        while value <= maxValue {
            let count = cells.reduce(0) { partial, tile in
                partial + ((tile?.value == value) ? 1 : 0)
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
        cells = Array(repeating: nil, count: Self.boardSize * Self.boardSize)
    }

    func tile(at position: GridPosition) -> Tile? {
        guard isValid(position) else { return nil }
        return cells[index(for: position)]
    }

    @discardableResult
    func place(_ newTile: Tile, at position: GridPosition) -> Bool {
        guard isValid(position), tile(at: position) == nil else { return false }
        cells[index(for: position)] = newTile
        return true
    }

    func move(_ direction: MoveDirection, commit: Bool = true) -> MoveResult {
        var working = cells
        var movements: [TileMovement] = []
        var merges: [MergeEvent] = []
        var didMove = false

        for from in traversalOrder(for: direction) {
            guard let sourceTile = tileFrom(board: working, at: from) else { continue }
            let to = steppedPosition(from: from, direction: direction)
            guard isValid(to) else { continue }

            if let targetTile = tileFrom(board: working, at: to) {
                guard let mergedTile = Tile.mergedValue(sourceTile, targetTile) else { continue }
                setTileIn(board: &working, position: from, tile: nil)
                setTileIn(board: &working, position: to, tile: mergedTile)
                movements.append(TileMovement(from: from, to: to, value: sourceTile.value, consumedInMerge: true))
                movements.append(TileMovement(from: to, to: to, value: targetTile.value, consumedInMerge: true))
                merges.append(MergeEvent(at: to, resultValue: mergedTile.value))
                score += mergedTile.value
                didMove = true
            } else {
                setTileIn(board: &working, position: from, tile: nil)
                setTileIn(board: &working, position: to, tile: sourceTile)
                movements.append(TileMovement(from: from, to: to, value: sourceTile.value, consumedInMerge: false))
                didMove = true
            }
        }

        if didMove && commit {
            cells = working
        }

        return MoveResult(
            didMove: didMove,
            movements: didMove ? movements : [],
            merges: didMove ? merges : [],
            spawnCandidates: didMove ? spawnCandidates(for: direction) : []
        )
    }

    private func traversalOrder(for direction: MoveDirection) -> [GridPosition] {
        let n = Self.boardSize
        switch direction {
        case .left:
            return (0..<n).flatMap { row in
                (1..<n).map { col in GridPosition(row: row, col: col) }
            }
        case .right:
            return (0..<n).flatMap { row in
                (0..<(n - 1)).reversed().map { col in GridPosition(row: row, col: col) }
            }
        case .up:
            return (1..<n).flatMap { row in
                (0..<n).map { col in GridPosition(row: row, col: col) }
            }
        case .down:
            return (0..<(n - 1)).reversed().flatMap { row in
                (0..<n).map { col in GridPosition(row: row, col: col) }
            }
        }
    }

    private func steppedPosition(from position: GridPosition, direction: MoveDirection) -> GridPosition {
        switch direction {
        case .left:
            return GridPosition(row: position.row, col: position.col - 1)
        case .right:
            return GridPosition(row: position.row, col: position.col + 1)
        case .up:
            return GridPosition(row: position.row - 1, col: position.col)
        case .down:
            return GridPosition(row: position.row + 1, col: position.col)
        }
    }

    private func spawnCandidates(for direction: MoveDirection) -> [GridPosition] {
        let n = Self.boardSize
        switch direction {
        case .left:
            return (0..<n).compactMap { row in
                let pos = GridPosition(row: row, col: n - 1)
                return tile(at: pos) == nil ? pos : nil
            }
        case .right:
            return (0..<n).compactMap { row in
                let pos = GridPosition(row: row, col: 0)
                return tile(at: pos) == nil ? pos : nil
            }
        case .up:
            return (0..<n).compactMap { col in
                let pos = GridPosition(row: n - 1, col: col)
                return tile(at: pos) == nil ? pos : nil
            }
        case .down:
            return (0..<n).compactMap { col in
                let pos = GridPosition(row: 0, col: col)
                return tile(at: pos) == nil ? pos : nil
            }
        }
    }

    private func allPositions() -> [GridPosition] {
        (0..<Self.boardSize).flatMap { row in
            (0..<Self.boardSize).map { col in
                GridPosition(row: row, col: col)
            }
        }
    }

    private func tileFrom(board: [Tile?], at position: GridPosition) -> Tile? {
        guard isValid(position) else { return nil }
        return board[index(for: position)]
    }

    private func setTileIn(board: inout [Tile?], position: GridPosition, tile: Tile?) {
        guard isValid(position) else { return }
        board[index(for: position)] = tile
    }

    private func index(for position: GridPosition) -> Int {
        position.row * Self.boardSize + position.col
    }

    private func isValid(_ position: GridPosition) -> Bool {
        (0..<Self.boardSize).contains(position.row) && (0..<Self.boardSize).contains(position.col)
    }

    private func hasAvailableMerge() -> Bool {
        for row in 0..<Self.boardSize {
            for col in 0..<Self.boardSize {
                let position = GridPosition(row: row, col: col)
                guard let currentTile = tile(at: position) else { continue }

                let right = GridPosition(row: row, col: col + 1)
                if let rightTile = tile(at: right), Tile.canMerge(currentTile, rightTile) {
                    return true
                }

                let down = GridPosition(row: row + 1, col: col)
                if let downTile = tile(at: down), Tile.canMerge(currentTile, downTile) {
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
