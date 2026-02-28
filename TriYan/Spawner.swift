import Foundation

final class Spawner {
    private(set) var previewTile: Tile

    init() {
        previewTile = Tile(1)
    }

    func reset(for board: [Tile?]) {
        previewTile = Spawner.rollBaseTile(for: board)
    }

    func takePreviewTile() -> Tile {
        previewTile
    }

    func refreshPreview(for board: [Tile?]) {
        previewTile = Spawner.rollBaseTile(for: board)
    }

    private static func rollBaseTile(for board: [Tile?]) -> Tile {
        var oneCount = 0
        var twoCount = 0
        var threeCount = 0
        var emptyCount = 0

        for tile in board {
            guard let tile else {
                emptyCount += 1
                continue
            }
            switch tile.value {
            case 1:
                oneCount += 1
            case 2:
                twoCount += 1
            case 3:
                threeCount += 1
            default:
                break
            }
        }

        var w1 = 3
        var w2 = 3
        var w3 = 2

        let imbalance = twoCount - oneCount
        if imbalance >= 2 {
            w1 += imbalance * 2
            w2 = max(1, w2 - imbalance)
        } else if imbalance <= -2 {
            let reversed = -imbalance
            w2 += reversed * 2
            w1 = max(1, w1 - reversed)
        }

        if oneCount == 0 {
            w1 += 4
        }
        if twoCount == 0 {
            w2 += 4
        }

        if emptyCount <= 4 {
            w1 += 2
            w2 += 1
            w3 = max(1, w3 - 1)
        }

        if emptyCount <= 2 {
            w3 = 0
        }

        if threeCount == 0 && oneCount > 0 && twoCount > 0 && emptyCount >= 6 {
            w3 += 1
        }

        let total = w1 + w2 + max(0, w3)
        guard total > 0 else { return Tile(1) }
        let roll = Int.random(in: 0..<total)
        if roll < w1 {
            return Tile(1)
        }
        if roll < (w1 + w2) {
            return Tile(2)
        }
        return Tile(3)
    }
}
