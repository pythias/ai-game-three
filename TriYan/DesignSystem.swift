import UIKit
import SpriteKit

enum DesignSystem {
    // MARK: - Colors
    enum Colors {
        // 背景
        static let background = UIColor(hex: "#1A6DD8")
        static let backgroundDeep = UIColor(hex: "#0D3A9E")
        static let backgroundGlow = UIColor(hex: "#4DB8FF")

        // 棋盘（深邃蜂窝底）
        static let boardDeep = UIColor(hex: "#0F4A9C")
        static let boardBackground = UIColor(hex: "#1A5BA8")
        static let boardRim = UIColor(hex: "#2980D4")

        // 空格（暗蓝半透明槽位，不再抢注意力）
        static let emptyCell = UIColor(hex: "#0A3476").withAlphaComponent(0.55)
        static let emptyCellStroke = UIColor(hex: "#1E5BB5").withAlphaComponent(0.35)

        // 文字
        static let textDark = UIColor.white
        static let textLight = UIColor.white

        // 分数/成就
        static let progressFill = UIColor(hex: "#FFE348")
        static let overlayScrim = UIColor.black.withAlphaComponent(0.38)

        // HUD 卡片
        static let cardBackground = UIColor(hex: "#1B5FAE").withAlphaComponent(0.92)
        static let cardStroke = UIColor.white.withAlphaComponent(0.38)

        // 按钮
        static let buttonBackground = UIColor(hex: "#1A6FE8")
        static let buttonSecondaryBackground = UIColor(hex: "#FFB800")
        static let buttonShadow = UIColor.black.withAlphaComponent(0.22)

        // 其他
        static let achievementBackground = UIColor(hex: "#174DB8")
        static let coinGold = UIColor(hex: "#FFC21D")
        static let badgeRed = UIColor(hex: "#F24835")

        // 棋子 3D 质感：底部深色（糖果暗边）
        static func tileBottomDark(for value: Int) -> UIColor {
            switch value {
            case 1: return UIColor(hex: "#2563A8")
            case 2: return UIColor(hex: "#3A7A0A")
            case 3: return UIColor(hex: "#1A7A6E")
            case 6: return UIColor(hex: "#A85A00")
            case 12: return UIColor(hex: "#5A24A8")
            case 24: return UIColor(hex: "#A88000")
            case 48: return UIColor(hex: "#A82010")
            case 96: return UIColor(hex: "#0A6090")
            case 192: return UIColor(hex: "#0A5840")
            case 384: return UIColor(hex: "#8010A0")
            default:
                if value >= 768 { return UIColor(hex: "#101A80") }
                return UIColor(hex: "#A89000")
            }
        }

        // ============================================================
        // Overlay / Menu 页面专用颜色（游戏化风格）
        // ============================================================

        /// 全屏遮罩深色渐变顶部
        static let overlayGradientTop = UIColor(hex: "#0C1B3E")
        /// 全屏遮罩深色渐变底部
        static let overlayGradientBottom = UIColor(hex: "#0A1428")
        /// 金色强调色（用于标题、高亮）
        static let goldAccent = UIColor(hex: "#FFD700")
        /// 金色强调色（暖调，比 goldAccent 柔和）
        static let goldWarm = UIColor(hex: "#FFB830")
        /// 琥珀色（用于次要金色）
        static let amber = UIColor(hex: "#FF9500")
        /// 遮罩层深色背景
        static let overlayDarkBg = UIColor(hex: "#0A0F1E").withAlphaComponent(0.92)
        /// 玻璃卡片背景
        static let glassCardBg = UIColor(hex: "#1A2848").withAlphaComponent(0.88)
        /// 玻璃卡片描边（金色微光）
        static let glassCardStroke = UIColor(hex: "#FFD700").withAlphaComponent(0.22)
        /// 玻璃卡片高光
        static let glassCardShine = UIColor.white.withAlphaComponent(0.12)
        /// 成就已解锁颜色
        static let achievementUnlocked = UIColor(hex: "#FFD700")
        /// 成就未解锁颜色
        static let achievementLocked = UIColor(hex: "#4A5A80")
        /// 排行榜第一名金色
        static let rankGold = UIColor(hex: "#FFD700")
        /// 排行榜第二名银色
        static let rankSilver = UIColor(hex: "#C0C0C0")
        /// 排行榜第三名铜色
        static let rankBronze = UIColor(hex: "#CD7F32")
        /// 分隔线颜色
        static let separator = UIColor.white.withAlphaComponent(0.12)
        /// Menu 页标题金色
        static let menuTitleGold = UIColor(hex: "#FFE066")
        /// 按钮主色（金色渐变底）
        static let primaryButtonGold = UIColor(hex: "#FFB800")
        /// 按钮暗边
        static let primaryButtonDark = UIColor(hex: "#CC8800")
        /// 文字次要色（柔和白）
        static let textSecondary = UIColor.white.withAlphaComponent(0.72)
        /// 文字次次要色
        static let textMuted = UIColor.white.withAlphaComponent(0.48)

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
            case 1: return UIColor(hex: "#B8DEFF")
            case 2: return UIColor(hex: "#C0FF50")
            case 3: return UIColor(hex: "#A0F0E8")
            case 6: return UIColor(hex: "#FFCC60")
            case 12: return UIColor(hex: "#D0A8FF")
            case 24: return UIColor(hex: "#FFFAA0")
            case 48: return UIColor(hex: "#FFB0A0")
            case 96: return UIColor(hex: "#A0E8FF")
            case 192: return UIColor(hex: "#90FFD0")
            case 384: return UIColor(hex: "#F0A0FF")
            default:
                if value >= 768 { return UIColor(hex: "#90A8FF") }
                return UIColor(hex: "#FFFAA0")
            }
        }

        static func tileText(for value: Int) -> UIColor {
            return .white
        }

        // 棋子外发光（即将合并时）
        static func tileGlow(for value: Int) -> UIColor {
            return tileHighlight(for: value).withAlphaComponent(0.6)
        }
    }

    // MARK: - Layout
    enum Layout {
        static let gridSpacing: CGFloat = 0
        static let cellCornerRadius: CGFloat = 0
        static let tileCornerRadius: CGFloat = 0
        static let gridWidthRatio: CGFloat = 0.95
        static let screenPadding: CGFloat = 20
        static let hudTopInset: CGFloat = 12
        static let hudTitleWidth: CGFloat = 88
        static let hudScoreWidth: CGFloat = 112
        static let hudButtonSize = CGSize(width: 36, height: 36)
        static let previewTileSize = CGSize(width: 32, height: 32)
        static let modalCardSize = CGSize(width: 314, height: 274)
        static let modalCornerRadius: CGFloat = 22
        static let modalButtonHeight: CGFloat = 48
        static let historyCardSize = CGSize(width: 336, height: 386)
        static let menuCardSize = CGSize(width: 296, height: 286)
        static let settingsCardSize = CGSize(width: 336, height: 338)
        static let infoCardSize = CGSize(width: 336, height: 376)
        static let titleCardSize = CGSize(width: 142, height: 52)
        static let nextCardSize = CGSize(width: 112, height: 60)
        static let scoreCardSize = CGSize(width: 226, height: 88)

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

        // ============================================================
        // Overlay / Menu 页面专用字体（游戏化风格）
        // ============================================================

        /// 页面大标题
        static func overlayTitleFont() -> UIFont {
            rounded(30, weight: .black)
        }

        /// 导航指示文字
        static func navHintFont() -> UIFont {
            rounded(12, weight: .medium)
        }

        /// 卡片行标题
        static func cardTitleFont() -> UIFont {
            rounded(16, weight: .bold)
        }

        /// 卡片行副标题
        static func cardSubtitleFont() -> UIFont {
            rounded(12, weight: .regular)
        }

        /// 主按钮文字
        static func primaryButtonFont() -> UIFont {
            rounded(18, weight: .black)
        }

        /// 排行榜数字
        static func rankNumberFont() -> UIFont {
            rounded(20, weight: .black)
        }

        /// 分数显示
        static func scoreDisplayFont() -> UIFont {
            rounded(22, weight: .black)
        }

        /// 迷你标签
        static func badgeFont() -> UIFont {
            rounded(10, weight: .bold)
        }

        static func tileFont(for value: Int) -> UIFont {
            let size: CGFloat
            if value < 100 {
                size = 52
            } else if value < 1000 {
                size = 44
            } else if value < 10000 {
                size = 36
            } else {
                size = 28
            }
            // 加粗 + 黑色重量感
            return rounded(size, weight: .black)
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
