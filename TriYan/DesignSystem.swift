import UIKit
import SpriteKit

enum DesignSystem {
    // MARK: - Colors
    enum Colors {
        static let emptyCell = UIColor(hex: "#245FC6")
        static let background = UIColor(hex: "#126FE8")
        static let backgroundDeep = UIColor(hex: "#2E24C8")
        static let backgroundGlow = UIColor(hex: "#27C7FF")
        static let textDark = UIColor.white
        static let textLight = UIColor.white
        static let progressFill = UIColor(hex: "#FFE348")
        static let overlayScrim = UIColor.black.withAlphaComponent(0.32)
        static let cardBackground = UIColor(hex: "#186DDE")
        static let cardStroke = UIColor.white.withAlphaComponent(0.46)
        static let boardBackground = UIColor(hex: "#2EA8FF")
        static let buttonBackground = UIColor(hex: "#1598F6")
        static let buttonSecondaryBackground = UIColor(hex: "#FFC319")
        static let achievementBackground = UIColor(hex: "#174DB8")
        static let coinGold = UIColor(hex: "#FFC21D")
        static let badgeRed = UIColor(hex: "#F24835")

        static func tileBackground(for value: Int) -> UIColor {
            switch value {
            case 1: return UIColor(hex: "#5AA8FF")
            case 2: return UIColor(hex: "#68D818")
            case 3: return UIColor(hex: "#42C4AF")
            case 6: return UIColor(hex: "#F58A00")
            case 12: return UIColor(hex: "#8D4EE8")
            case 24: return UIColor(hex: "#FFD723")
            case 48: return UIColor(hex: "#EF4E39")
            case 96: return UIColor(hex: "#2BB5F4")
            case 192: return UIColor(hex: "#20A46D")
            case 384: return UIColor(hex: "#C33AE0")
            default:
                if value >= 768 { return UIColor(hex: "#243FBA") }
                return UIColor(hex: "#FFD64D")
            }
        }

        static func tileHighlight(for value: Int) -> UIColor {
            switch value {
            case 1: return UIColor(hex: "#9FD0FF")
            case 2: return UIColor(hex: "#B8F64F")
            case 3: return UIColor(hex: "#76E7DA")
            case 6: return UIColor(hex: "#FFB329")
            case 12: return UIColor(hex: "#B986FF")
            case 24: return UIColor(hex: "#FFF36C")
            case 48: return UIColor(hex: "#FF7A62")
            case 96: return UIColor(hex: "#76D8FF")
            case 192: return UIColor(hex: "#5BE09D")
            case 384: return UIColor(hex: "#E277FF")
            default:
                if value >= 768 { return UIColor(hex: "#6078FF") }
                return UIColor(hex: "#FFF16C")
            }
        }

        static func tileText(for value: Int) -> UIColor {
            switch value {
            case 6, 24, 48:
                return .white
            default:
                return UIColor(hex: "#F7FFF9")
            }
        }
    }

    // MARK: - Layout
    enum Layout {
        static let gridSpacing: CGFloat = 0
        static let cellCornerRadius: CGFloat = 0
        static let tileCornerRadius: CGFloat = 0
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
        static let menuCardSize = CGSize(width: 296, height: 286)
        static let settingsCardSize = CGSize(width: 336, height: 338)
        static let infoCardSize = CGSize(width: 336, height: 376)
        static let titleCardSize = CGSize(width: 142, height: 52)
        static let nextCardSize = CGSize(width: 154, height: 62)
        static let scoreCardSize = CGSize(width: 230, height: 82)

        static func gridSize(in view: SKView) -> CGFloat {
            view.bounds.width * gridWidthRatio
        }

        static func cellSize(gridSize: CGFloat) -> CGFloat {
            gridSize / 5
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
