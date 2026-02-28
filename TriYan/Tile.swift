import Foundation

enum TileType: Equatable {
    case baseOne
    case baseTwo
    case number
}

struct Tile: Equatable {
    let value: Int

    init(_ value: Int) {
        self.value = value
    }

    var type: TileType {
        switch value {
        case 1:
            return .baseOne
        case 2:
            return .baseTwo
        default:
            return .number
        }
    }

    static func canMerge(_ lhs: Tile, _ rhs: Tile) -> Bool {
        return mergedValue(lhs, rhs) != nil
    }

    static func mergedValue(_ lhs: Tile, _ rhs: Tile) -> Tile? {
        if (lhs.value == 1 && rhs.value == 2) || (lhs.value == 2 && rhs.value == 1) {
            return Tile(3)
        }
        if lhs.value >= 3 && lhs.value == rhs.value {
            return Tile(lhs.value * 2)
        }
        return nil
    }
}
