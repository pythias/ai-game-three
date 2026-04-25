import UIKit
import SpriteKit

enum DesignSystem {
    // MARK: - Colors
    enum Colors {
        static let emptyCell = UIColor(hex: "#D5C3AD")
        static let background = UIColor(hex: "#F5EBDD")
        static let backgroundDeep = UIColor(hex: "#DDC4A8")
        static let backgroundGlow = UIColor(hex: "#FFF4DF")
        static let textDark = UIColor(hex: "#493F37")
        static let textLight = UIColor.white
        static let progressFill = UIColor(hex: "#1F7A68")
        static let overlayScrim = UIColor.black.withAlphaComponent(0.28)
        static let cardBackground = UIColor(hex: "#FFF8EE")
        static let cardStroke = UIColor.white.withAlphaComponent(0.72)
        static let boardBackground = UIColor(hex: "#B99E82")
        static let buttonBackground = UIColor(hex: "#D86E3E")
        static let buttonSecondaryBackground = UIColor(hex: "#F1DBC4")
        static let achievementBackground = UIColor(hex: "#1F7A68")

        static func tileBackground(for value: Int) -> UIColor {
            switch value {
            case 1: return UIColor(hex: "#FFFDF7")
            case 2: return UIColor(hex: "#E85C4A")
            case 3: return UIColor(hex: "#F4A6A0")
            case 6: return UIColor(hex: "#E77E45")
            case 12: return UIColor(hex: "#E5B64A")
            case 24: return UIColor(hex: "#C89D3F")
            case 48: return UIColor(hex: "#A8A941")
            case 96: return UIColor(hex: "#6AA85D")
            case 192: return UIColor(hex: "#36956F")
            case 384: return UIColor(hex: "#27868A")
            default:
                if value >= 768 { return UIColor(hex: "#2D76A5") }
                return UIColor(hex: "#BBA88F")
            }
        }

        static func tileHighlight(for value: Int) -> UIColor {
            switch value {
            case 1: return UIColor(hex: "#FFFFFF")
            case 2: return UIColor(hex: "#FF8A78")
            case 3: return UIColor(hex: "#FFD2CC")
            case 6: return UIColor(hex: "#FFAA68")
            case 12: return UIColor(hex: "#F7D46B")
            case 24: return UIColor(hex: "#E7C35D")
            case 48: return UIColor(hex: "#CCCF66")
            case 96: return UIColor(hex: "#91C980")
            case 192: return UIColor(hex: "#5DBF91")
            case 384: return UIColor(hex: "#4DB0B3")
            default:
                if value >= 768 { return UIColor(hex: "#5DA9D0") }
                return UIColor(hex: "#D1C2AA")
            }
        }

        static func tileText(for value: Int) -> UIColor {
            switch value {
            case 1: return UIColor(hex: "#9A8C7D")
            case 12, 24: return UIColor(hex: "#4F453B")
            default: return .white
            }
        }
    }

    // MARK: - Layout
    enum Layout {
        static let gridSpacing: CGFloat = 10
        static let cellCornerRadius: CGFloat = 14
        static let tileCornerRadius: CGFloat = 14
        static let gridWidthRatio: CGFloat = 0.88
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
        static let nextCardSize = CGSize(width: 104, height: 86)
        static let scoreCardSize = CGSize(width: 112, height: 72)

        static func gridSize(in view: SKView) -> CGFloat {
            view.bounds.width * gridWidthRatio
        }

        static func cellSize(gridSize: CGFloat) -> CGFloat {
            (gridSize - 3 * gridSpacing) / 4
        }
    }

    // MARK: - Animation
    enum Animation {
        static let moveDuration: TimeInterval = 0.11
        static let spawnDuration: TimeInterval = 0.1
        static let mergeDuration: TimeInterval = 0.13
        static let previewDuration: TimeInterval = 0.1
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
            rounded(32, weight: .black)
        }

        static func hudLabelFont() -> UIFont {
            rounded(16, weight: .semibold)
        }

        static func hudValueFont() -> UIFont {
            rounded(22, weight: .bold)
        }

        static func hudSmallFont() -> UIFont {
            rounded(12, weight: .semibold)
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
