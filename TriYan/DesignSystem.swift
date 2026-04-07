//
//  DesignSystem.swift
//  merge3
//
//  Design System - Centralized design constants for TriYan
//

import SpriteKit

// MARK: - Color Palette

struct DesignColors {
    // Background colors
    static let background = SKColor(red: 0.97, green: 0.965, blue: 0.94, alpha: 1.0)       // #F8F6F0
    static let boardBase = SKColor(red: 0.91, green: 0.878, blue: 0.835, alpha: 1.0)        // #E8E0D5
    static let cellFill = SKColor(red: 0.96, green: 0.941, blue: 0.91, alpha: 1.0)          // #F5F0E8

    // Card colors - vibrant and distinct
    static let card1 = SKColor(red: 1.0, green: 0.961, blue: 0.882, alpha: 1.0)             // #FFF5E1 (奶白)
    static let card2 = SKColor(red: 1.0, green: 0.894, blue: 0.769, alpha: 1.0)            // #FFE4C4 (浅杏)
    static let card3 = SKColor(red: 1.0, green: 0.851, blue: 0.239, alpha: 1.0)            // #FFD93D (明黄) ⭐
    static let card6 = SKColor(red: 1.0, green: 0.549, blue: 0.259, alpha: 1.0)             // #FF8C42 (橙色)
    static let card12 = SKColor(red: 1.0, green: 0.42, blue: 0.42, alpha: 1.0)            // #FF6B6B (珊瑚红)
    static let card24 = SKColor(red: 0.769, green: 0.271, blue: 0.412, alpha: 1.0)         // #C44569 (玫红)
    static let card48 = SKColor(red: 0.424, green: 0.357, blue: 0.482, alpha: 1.0)         // #6C5B7B (深紫)
    static let card96Plus = SKColor(red: 0.176, green: 0.188, blue: 0.278, alpha: 1.0)     // #2D3047 (深蓝)

    // UI Colors
    static let primaryButton = SKColor(red: 0.47, green: 0.50, blue: 0.59, alpha: 1.0)
    static let textPrimary = SKColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1.0)         // 深灰
    static let textSecondary = SKColor(red: 0.45, green: 0.48, blue: 0.55, alpha: 1.0)      // 中灰
    static let overlayBackground = SKColor(red: 0.95, green: 0.96, blue: 0.97, alpha: 1.0)

    // Text colors for cards
    static let cardTextLight = SKColor.white
    static let cardTextDark = SKColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)

    // Accent colors
    static let highlight = SKColor(red: 1.0, green: 0.75, blue: 0.3, alpha: 1.0)            // 橙色高光
    static let success = SKColor(red: 0.4, green: 0.8, blue: 0.4, alpha: 1.0)
    static let gold = SKColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)                // 金色

    static func cardColor(for value: Int) -> SKColor {
        switch value {
        case 1: return card1
        case 2: return card2
        case 3: return card3
        case 6: return card6
        case 12: return card12
        case 24: return card24
        case 48: return card48
        default: return card96Plus
        }
    }

    static func cardTextColor(for value: Int) -> SKColor {
        switch value {
        case 1, 2, 3: return cardTextDark
        default: return cardTextLight
        }
    }
}

// MARK: - Typography

struct DesignFonts {
    static let fontName = "AvenirNext-Bold"
    static let fontNameMedium = "AvenirNext-Medium"
    static let fontNameHeavy = "AvenirNext-Heavy"

    // Font sizes - upgraded for better hierarchy
    static let cardNumber: CGFloat = 28       // +2 from 26
    static let previewNumber: CGFloat = 36   // +4 from 32
    static let largeNumber: CGFloat = 20     // -2 from 22 (for 100+)
    static let title: CGFloat = 32            // +2 from 30
    static let button: CGFloat = 14           // +2 from 12
    static let body: CGFloat = 16
    static let caption: CGFloat = 12
    static let score: CGFloat = 28            // For real-time score display

    static func cardFontSize(for value: Int) -> CGFloat {
        if value >= 100 {
            return largeNumber
        } else if value >= 10 {
            return cardNumber - 2
        }
        return cardNumber
    }

    static func previewFontSize(for value: Int) -> CGFloat {
        if value >= 100 {
            return previewNumber - 6
        } else if value >= 10 {
            return previewNumber - 2
        }
        return previewNumber
    }
}

// MARK: - Spacing & Layout

struct DesignSpacing {
    static let tileSide: CGFloat = 52
    static let tileSpacing: CGFloat = 6
    static let cornerRadius: CGFloat = 8
    static let cornerRadiusSmall: CGFloat = 5

    static let buttonWidth: CGFloat = 92
    static let buttonHeight: CGFloat = 56
    static let buttonCornerRadius: CGFloat = 12

    static let previewScale: CGFloat = 0.72
    static let hudTopMargin: CGFloat = 50
    static let hudSideMargin: CGFloat = 20
}

// MARK: - Animation Timing

struct DesignAnimation {
    static let moveDuration: TimeInterval = 0.15        // Slightly slower for elegance
    static let mergeScaleUp: TimeInterval = 0.08
    static let mergeScaleDown: TimeInterval = 0.1
    static let spawnDuration: TimeInterval = 0.12
    static let popupDuration: TimeInterval = 0.2
    static let flashDuration: TimeInterval = 0.05

    // Settlement
    static let settlementStepDuration: TimeInterval = 1.0
    static let settlementBonusFlyDuration: TimeInterval = 0.8

    // UI Feedback
    static let buttonFeedbackDuration: TimeInterval = 0.1
    static let scorePopDuration: TimeInterval = 0.3
}

// MARK: - Special Effects

struct DesignEffects {
    // Merge glow
    static let mergeGlowColor = SKColor.white
    static let mergeGlowAlpha: CGFloat = 0.6
    static let mergeGlowDuration: TimeInterval = 0.15

    // Pulse effect
    static let pulseScale: CGFloat = 1.15
    static let pulseDuration: TimeInterval = 0.18

    // Screen shake
    static let shakeIntensity: CGFloat = 3.0
    static let shakeDuration: TimeInterval = 0.2

    // Score pop
    static let scorePopOffset: CGFloat = 40
    static let scorePopScale: CGFloat = 1.3

    // Game over
    static let gameOverFadeAlpha: CGFloat = 0.4

    // New record glow
    static let recordGlowColor = SKColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
}
