import UIKit
import SpriteKit

enum DesignSystem {
    // MARK: - Colors
    enum Colors {
        static let emptyCell = UIColor(hex: "#CDC1B4")
        static let background = UIColor(hex: "#FAF8EF")
        static let textDark = UIColor(hex: "#776E65")
        static let textLight = UIColor.white
        static let overlayScrim = UIColor.black.withAlphaComponent(0.28)
        static let cardBackground = UIColor(hex: "#FFF8EE")
        static let buttonBackground = UIColor(hex: "#F08B4B")
        static let buttonSecondaryBackground = UIColor(hex: "#F2E5D5")
        static let achievementBackground = UIColor(hex: "#3C7D6B")

        static func tileBackground(for value: Int) -> UIColor {
            switch value {
            case 1: return UIColor(hex: "#FFFFFF")
            case 2: return UIColor(hex: "#FF3344")
            case 3: return UIColor(hex: "#FF99AA")
            case 6: return UIColor(hex: "#FF7744")
            case 12: return UIColor(hex: "#FFCC33")
            case 24: return UIColor(hex: "#DDAA22")
            case 48: return UIColor(hex: "#BBBB33")
            case 96: return UIColor(hex: "#88CC44")
            case 192: return UIColor(hex: "#44BB66")
            case 384: return UIColor(hex: "#33AA88")
            default:
                if value >= 768 { return UIColor(hex: "#33AACC") }
                return UIColor(hex: "#CDC1B4")
            }
        }

        static func tileText(for value: Int) -> UIColor {
            switch value {
            case 1: return UIColor(hex: "#A39C90")
            case 12: return UIColor(hex: "#776E65")
            default: return .white
            }
        }
    }

    // MARK: - Layout
    enum Layout {
        static let gridSpacing: CGFloat = 8
        static let cellCornerRadius: CGFloat = 8
        static let tileCornerRadius: CGFloat = 6
        static let gridWidthRatio: CGFloat = 0.9
        static let screenPadding: CGFloat = 20
        static let hudTopInset: CGFloat = 12
        static let hudTitleWidth: CGFloat = 88
        static let hudScoreWidth: CGFloat = 112
        static let hudButtonSize = CGSize(width: 36, height: 36)
        static let previewTileSize = CGSize(width: 42, height: 42)
        static let modalCardSize = CGSize(width: 314, height: 274)
        static let modalCornerRadius: CGFloat = 22
        static let modalButtonHeight: CGFloat = 48
        static let historyCardSize = CGSize(width: 336, height: 386)

        static func gridSize(in view: SKView) -> CGFloat {
            view.bounds.width * gridWidthRatio
        }

        static func cellSize(gridSize: CGFloat) -> CGFloat {
            (gridSize - 3 * gridSpacing) / 4
        }
    }

    // MARK: - Animation
    enum Animation {
        static let moveDuration: TimeInterval = 0.15
        static let spawnDuration: TimeInterval = 0.15
        static let mergeDuration: TimeInterval = 0.2
        static let previewDuration: TimeInterval = 0.16
    }

    // MARK: - Fonts
    enum Fonts {
        private static func rounded(_ size: CGFloat, weight: UIFont.Weight) -> UIFont {
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            if let descriptor = base.fontDescriptor.withDesign(.rounded) {
                return UIFont(descriptor: descriptor, size: size)
            }
            return base
        }

        static func titleFont() -> UIFont {
            rounded(30, weight: .heavy)
        }

        static func hudLabelFont() -> UIFont {
            rounded(16, weight: .semibold)
        }

        static func hudValueFont() -> UIFont {
            rounded(22, weight: .bold)
        }

        static func buttonFont() -> UIFont {
            rounded(18, weight: .bold)
        }

        static func modalTitleFont() -> UIFont {
            rounded(28, weight: .heavy)
        }

        static func modalValueFont() -> UIFont {
            rounded(22, weight: .bold)
        }

        static func historyRowTitleFont() -> UIFont {
            rounded(18, weight: .bold)
        }

        static func historyRowBodyFont() -> UIFont {
            rounded(14, weight: .medium)
        }

        static func achievementFont() -> UIFont {
            rounded(16, weight: .bold)
        }

        static func tileFont(for value: Int) -> UIFont {
            let size: CGFloat
            if value < 100 {
                size = 48
            } else if value < 1000 {
                size = 40
            } else if value < 10000 {
                size = 32
            } else {
                size = 24
            }
            return rounded(size, weight: .bold)
        }
    }
}

// MARK: - UIColor Hex Extension
extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
