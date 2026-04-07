//
//  EffectsManager.swift
//  merge3
//
//  Visual Effects Manager - Handles all visual effects in the game
//

import SpriteKit

final class EffectsManager {
    private weak var scene: SKScene?
    private var particleNodes: [SKEmitterNode] = []

    init(scene: SKScene) {
        self.scene = scene
        self.scene?.addChild(effectsNode)
    }

    private let effectsNode = SKNode()

    // MARK: - Merge Effects

    /// Play enhanced merge animation with glow effect
    func playMergeEffect(on node: SKShapeNode, completion: (() -> Void)? = nil) {
        guard let scene = scene else { return }

        // Scale bounce animation
        let scaleUp = SKAction.scale(to: DesignEffects.pulseScale, duration: DesignAnimation.mergeScaleUp)
        scaleUp.timingMode = .easeOut

        let scaleDown = SKAction.scale(to: 1.0, duration: DesignAnimation.mergeScaleDown)
        scaleDown.timingMode = .easeInEaseOut

        let bounce = SKAction.sequence([scaleUp, scaleDown])
        node.run(bounce)

        // Flash effect
        let flash = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: DesignAnimation.flashDuration),
            SKAction.fadeAlpha(to: 1.0, duration: DesignAnimation.flashDuration * 2)
        ])
        node.run(flash)

        // Glow effect (brief white overlay)
        let glowNode = createGlowOverlay()
        node.addChild(glowNode)
        glowNode.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.4, duration: DesignAnimation.flashDuration),
            SKAction.fadeOut(withDuration: DesignEffects.mergeGlowDuration),
            SKAction.removeFromParent()
        ]))

        // Particle burst for important merges
        if let tileValue = extractTileValue(from: node), tileValue >= 6 {
            effectsNode.run(.wait(forDuration: DesignAnimation.mergeScaleUp)) { [weak self] in
                self?.createMergeParticles(at: node.position, value: tileValue)
            }
        }

        completion?()
    }

    private func createGlowOverlay() -> SKShapeNode {
        let glow = SKShapeNode(rectOf: CGSize(width: 100, height: 100))
        glow.fillColor = DesignEffects.mergeGlowColor
        glow.alpha = 0
        glow.zPosition = 10
        return glow
    }

    private func extractTileValue(from node: SKShapeNode) -> Int? {
        for child in node.children {
            if let label = child as? SKLabelNode, let value = Int(label.text ?? "") {
                return value
            }
        }
        return nil
    }

    // MARK: - Particle Effects

    private func createMergeParticles(at position: CGPoint, value: Int) {
        guard let scene = scene else { return }

        let particleColor: SKColor
        switch value {
        case 6: particleColor = DesignColors.card6
        case 12: particleColor = DesignColors.card12
        case 24: particleColor = DesignColors.card24
        case 48: particleColor = DesignColors.card48
        default: particleColor = DesignColors.card96Plus
        }

        // Create simple particle burst using SpriteKit
        for _ in 0..<8 {
            let particle = SKShapeNode(circleOfRadius: 3)
            particle.fillColor = particleColor
            particle.strokeColor = .clear
            particle.position = position
            particle.alpha = 0.8
            scene.addChild(particle)

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 20...40)
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance

            let move = SKAction.move(by: CGVector(dx: dx, dy: dy), duration: 0.3)
            move.timingMode = .easeOut

            let fade = SKAction.fadeOut(withDuration: 0.3)

            particle.run(.sequence([move, fade, SKAction.removeFromParent()]))
        }
    }

    // MARK: - Screen Effects

    /// Shake the screen slightly for impact feedback
    func screenShake(intensity: CGFloat = DesignEffects.shakeIntensity) {
        guard let scene = scene else { return }

        let originalPosition = scene.position
        let shakeCount = 6
        let shakeDuration = DesignEffects.shakeDuration / Double(shakeCount)

        var actions: [SKAction] = []
        for i in 0..<shakeCount {
            let offsetX = CGFloat.random(in: -intensity...intensity)
            let offsetY = CGFloat.random(in: -intensity...intensity)
            let move = SKAction.move(to: CGPoint(
                x: originalPosition.x + offsetX,
                y: originalPosition.y + offsetY
            ), duration: shakeDuration)
            actions.append(move)
        }

        // Return to original
        actions.append(SKAction.move(to: originalPosition, duration: shakeDuration))

        effectsNode.run(.sequence(actions))
    }

    // MARK: - Score Animations

    /// Animate score increase with pop effect
    func animateScorePop(on label: SKLabelNode, from oldValue: Int, to newValue: Int) {
        guard newValue > oldValue else { return }

        // Pop animation
        let scaleUp = SKAction.scale(to: DesignEffects.scorePopScale, duration: DesignAnimation.scorePopDuration * 0.5)
        scaleUp.timingMode = .easeOut

        let scaleDown = SKAction.scale(to: 1.0, duration: DesignAnimation.scorePopDuration * 0.5)
        scaleDown.timingMode = .easeInEaseOut

        label.run(.sequence([scaleUp, scaleDown]))

        // Flash color
        let originalColor = label.fontColor
        label.run(.sequence([
            SKAction.wait(forDuration: DesignAnimation.scorePopDuration * 0.3),
            SKAction.customAction(withDuration: DesignAnimation.scorePopDuration * 0.4) { node, _ in
                if let label = node as? SKLabelNode {
                    label.fontColor = DesignColors.highlight
                }
            },
            SKAction.customAction(withDuration: DesignAnimation.scorePopDuration * 0.3) { node, _ in
                if let label = node as? SKLabelNode {
                    label.fontColor = originalColor
                }
            }
        ]))
    }

    // MARK: - Settlement Effects

    /// Create flying bonus label during settlement
    func createFlyingBonus(text: String, at position: CGPoint, color: SKColor) -> SKLabelNode {
        guard let scene = scene else {
            let label = SKLabelNode(fontNamed: DesignFonts.fontNameHeavy)
            return label
        }

        let label = SKLabelNode(fontNamed: DesignFonts.fontNameHeavy)
        label.text = text
        label.fontSize = 32
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = position
        label.zPosition = 100
        label.setScale(0.5)
        scene.addChild(label)

        // Fly up and fade
        let flyUp = SKAction.move(by: CGVector(dx: 0, dy: DesignEffects.scorePopOffset), duration: DesignAnimation.settlementBonusFlyDuration)
        flyUp.timingMode = .easeOut

        let scaleUp = SKAction.scale(to: 1.2, duration: DesignAnimation.settlementBonusFlyDuration * 0.5)
        scaleUp.timingMode = .easeOut

        let fadeOut = SKAction.fadeOut(withDuration: DesignAnimation.settlementBonusFlyDuration * 0.5)
        fadeOut.timingMode = .easeIn

        let group = SKAction.group([flyUp, scaleUp, fadeOut])

        label.run(.sequence([group, SKAction.removeFromParent()]))

        return label
    }

    // MARK: - New Record Celebration

    func playNewRecordEffect(completion: (() -> Void)? = nil) {
        guard let scene = scene else { return }

        // Golden glow animation
        let glowNode = SKShapeNode(rectOf: scene.size)
        glowNode.fillColor = DesignEffects.recordGlowColor
        glowNode.alpha = 0
        glowNode.zPosition = 50
        scene.addChild(glowNode)

        let fadeIn = SKAction.fadeAlpha(to: 0.3, duration: 0.3)
        let fadeOut = SKAction.fadeAlpha(to: 0, duration: 0.5)
        let pulse = SKAction.sequence([fadeIn, fadeOut, SKAction.removeFromParent()])

        glowNode.run(pulse)

        // Particle celebration
        createCelebrationParticles()

        completion?()
    }

    private func createCelebrationParticles() {
        guard let scene = scene else { return }

        let colors: [SKColor] = [
            DesignEffects.recordGlowColor,
            DesignColors.card3,
            DesignColors.card6,
            DesignColors.card12
        ]

        for _ in 0..<20 {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...5))
            particle.fillColor = colors.randomElement() ?? DesignEffects.recordGlowColor
            particle.strokeColor = .clear
            particle.position = CGPoint(
                x: CGFloat.random(in: 0...scene.size.width),
                y: scene.size.height + 20
            )
            particle.alpha = 0.9
            particle.zPosition = 51
            scene.addChild(particle)

            let fallDistance = scene.size.height + 40
            let duration = CGFloat.random(in: 0.8...1.5)
            let dx = CGFloat.random(in: -50...50)

            let fall = SKAction.move(by: CGVector(dx: dx, dy: -fallDistance), duration: duration)
            fall.timingMode = .easeIn

            let rotate = SKAction.rotate(byAngle: .pi * 2, duration: duration)

            let fadeOut = SKAction.fadeOut(withDuration: duration * 0.5)

            let group = SKAction.group([fall, rotate, fadeOut])

            particle.run(.sequence([group, SKAction.removeFromParent()]))
        }
    }

    // MARK: - Button Feedback

    func playButtonTap(on node: SKShapeNode) {
        let scaleDown = SKAction.scale(to: 0.95, duration: DesignAnimation.buttonFeedbackDuration)
        scaleDown.timingMode = .easeOut

        let scaleUp = SKAction.scale(to: 1.0, duration: DesignAnimation.buttonFeedbackDuration)
        scaleUp.timingMode = .easeInEaseOut

        node.run(.sequence([scaleDown, scaleUp]))
    }

    // MARK: - Game Over Effects

    func applyGameOverStyle(to nodes: [SKShapeNode]) {
        for node in nodes {
            let fade = SKAction.fadeAlpha(to: DesignEffects.gameOverFadeAlpha, duration: 0.3)
            node.run(fade)
        }
    }

    // MARK: - Spawn Effect

    func playSpawnEffect(on node: SKShapeNode) {
        node.setScale(0.6)
        let scaleUp = SKAction.scale(to: 1.0, duration: DesignAnimation.spawnDuration)
        scaleUp.timingMode = .easeOut
        node.run(scaleUp)
    }

    // MARK: - Combo Indicator

    func showComboIndicator(text: String, at position: CGPoint) -> SKLabelNode {
        guard let scene = scene else {
            let label = SKLabelNode(fontNamed: DesignFonts.fontNameHeavy)
            return label
        }

        // Adaptive font size based on text length
        let fontSize: CGFloat = text.count > 12 ? 24 : (text.count > 8 ? 28 : 32)

        let label = SKLabelNode(fontNamed: DesignFonts.fontNameHeavy)
        label.text = text
        label.fontSize = fontSize
        label.fontColor = DesignColors.highlight
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = position
        label.zPosition = 100
        label.alpha = 0
        label.setScale(1.2)
        scene.addChild(label)

        // Pop in
        let fadeIn = SKAction.fadeIn(withDuration: 0.15)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.2)
        scaleDown.timingMode = .easeOut

        // Hold and fade out
        let wait = SKAction.wait(forDuration: 0.5)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)

        label.run(.sequence([SKAction.group([fadeIn, scaleDown]), wait, fadeOut, SKAction.removeFromParent()]))

        return label
    }

    // MARK: - Cleanup

    func cleanup() {
        for node in particleNodes {
            node.removeFromParent()
        }
        particleNodes.removeAll()
    }
}
