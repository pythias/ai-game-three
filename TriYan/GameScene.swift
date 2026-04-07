//
//  GameScene.swift
//  merge3
//
//  Created by 陈杰 on 2026/2/28.
//

import SpriteKit

final class GameScene: SKScene {
    private enum ScenePhase {
        case playing
        case gameOverPrompt
        case settlement
    }

    private enum OverlayPage {
        case none
        case menu
        case stats
    }

    private enum TutorialPhase {
        case none
        case welcome
        case step1Merge12     // 1+2=3
        case step2Merge33    // 3+3=6
        case step3FreePlay   // 自由游戏
    }

    private let model = GameModel()
    private let spawner = Spawner()
    private let statsStore = StatsStore.shared
    private let gameCenterService = GameCenterService.shared

    // Effects Manager
    private var effectsManager: EffectsManager?

    private var inputController: InputController?
    private var tileNodes: [GridPosition: SKShapeNode] = [:]
    private var isAnimatingMove = false
    private var hasStartedGame = false

    // Combo tracking
    private var consecutiveMerges = 0
    private var lastMergeCount = 0

    // Tutorial
    private var tutorialPhase: TutorialPhase = .none
    private var tutorialArrowNode = SKShapeNode()
    private var tutorialInstructionLabel = SKLabelNode(fontNamed: DesignFonts.fontNameMedium)
    private var tutorialHighlightNode = SKShapeNode()

    private let boardNode = SKNode()
    private let tileLayerNode = SKNode()
    private let hudNode = SKNode()

    // HUD Elements
    private let menuButtonNode = SKShapeNode()
    private let menuIconLabel = SKLabelNode(fontNamed: DesignFonts.fontName)
    private let menuTextLabel = SKLabelNode(fontNamed: DesignFonts.fontNameMedium)
    private let statsButtonNode = SKShapeNode()
    private let statsIconLabel = SKLabelNode(fontNamed: DesignFonts.fontName)
    private let statsTextLabel = SKLabelNode(fontNamed: DesignFonts.fontNameMedium)

    // Score display (new)
    private let scoreLabel = SKLabelNode(fontNamed: DesignFonts.fontName)
    private let scoreValueLabel = SKLabelNode(fontNamed: DesignFonts.fontNameHeavy)

    private let nextTitleLabel = SKLabelNode(fontNamed: DesignFonts.fontNameMedium)
    private let nextPreviewTileNode = SKShapeNode()
    private let nextPreviewValueLabel = SKLabelNode(fontNamed: DesignFonts.fontName)
    private let tipsLabel = SKLabelNode(fontNamed: DesignFonts.fontNameMedium)

    private let overlayNode = SKNode()
    private let overlayDimNode = SKShapeNode()
    private let overlayPanelNode = SKShapeNode()
    private let overlayTitleLabel = SKLabelNode(fontNamed: DesignFonts.fontName)
    private let overlayContentNode = SKNode()
    private let overlayCloseNode = SKShapeNode()
    private let overlayCloseLabel = SKLabelNode(fontNamed: DesignFonts.fontName)
    private var activeOverlay: OverlayPage = .none
    private var hasSubmittedCurrentGame = false
    private var scenePhase: ScenePhase = .playing
    private var cachedBoardMetrics: (tileSide: CGFloat, spacing: CGFloat, cornerRadius: CGFloat) = (52, 6, 8)
    private var cachedBoardFrame: CGRect = .zero
    private let settlementEffectNode = SKNode()
    private var settlementSteps: [(value: Int, count: Int)] = []
    private var settlementStepIndex = 0
    private var settlementRunningTotal = 0
    private var settlementCurrentValue = 0
    private let softScoreColor = SKColor(red: 0.38, green: 0.43, blue: 0.50, alpha: 1.0)
    private var globalLeaderboardEntries: [LeaderboardEntry] = []
    private var isLoadingGlobalLeaderboard = false

    // Previous score for animation
    private var previousScore = 0

    override func didMove(to view: SKView) {
        // Initialize effects manager
        effectsManager = EffectsManager(scene: self)

        if boardNode.parent == nil {
            backgroundColor = DesignColors.background
            addChild(boardNode)
            addChild(tileLayerNode)
            addChild(hudNode)
            configureHUD()
            installInput(on: view)
        }

        layoutScene()

        if !hasStartedGame {
            let isFirstTime = !UserDefaults.standard.bool(forKey: "hasSeenTutorial")
            startNewGame(isTutorial: isFirstTime)
            hasStartedGame = true
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutScene()
        rebuildTileNodes(popAt: [])
    }

    private func configureHUD() {
        // Menu button
        menuButtonNode.name = "menuButton"
        menuButtonNode.fillColor = DesignColors.primaryButton
        menuButtonNode.strokeColor = .clear
        hudNode.addChild(menuButtonNode)

        menuIconLabel.text = "≡"
        menuIconLabel.fontSize = 22
        menuIconLabel.fontColor = .white
        menuIconLabel.verticalAlignmentMode = .center
        menuIconLabel.horizontalAlignmentMode = .center
        menuIconLabel.position = CGPoint(x: 0, y: 3)
        menuButtonNode.addChild(menuIconLabel)

        menuTextLabel.text = "菜单"
        menuTextLabel.fontSize = DesignFonts.button
        menuTextLabel.fontColor = DesignColors.textPrimary
        menuTextLabel.verticalAlignmentMode = .center
        menuTextLabel.horizontalAlignmentMode = .center
        menuTextLabel.position = CGPoint(x: 0, y: -40)
        menuButtonNode.addChild(menuTextLabel)

        // Stats button
        statsButtonNode.name = "statsButton"
        statsButtonNode.fillColor = DesignColors.primaryButton
        statsButtonNode.strokeColor = .clear
        hudNode.addChild(statsButtonNode)

        statsIconLabel.text = "▮▮▮"
        statsIconLabel.fontSize = 18
        statsIconLabel.fontColor = .white
        statsIconLabel.verticalAlignmentMode = .center
        statsIconLabel.horizontalAlignmentMode = .center
        statsIconLabel.position = CGPoint(x: 0, y: 3)
        statsButtonNode.addChild(statsIconLabel)

        statsTextLabel.text = "统计"
        statsTextLabel.fontSize = DesignFonts.button
        statsTextLabel.fontColor = DesignColors.textPrimary
        statsTextLabel.verticalAlignmentMode = .center
        statsTextLabel.horizontalAlignmentMode = .center
        statsTextLabel.position = CGPoint(x: 0, y: -40)
        statsButtonNode.addChild(statsTextLabel)

        // Score display (new)
        scoreLabel.text = "分数"
        scoreLabel.fontSize = DesignFonts.button
        scoreLabel.fontColor = DesignColors.textPrimary
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.horizontalAlignmentMode = .center
        hudNode.addChild(scoreLabel)

        scoreValueLabel.text = "0"
        scoreValueLabel.fontSize = DesignFonts.score
        scoreValueLabel.fontColor = DesignColors.textPrimary
        scoreValueLabel.verticalAlignmentMode = .center
        scoreValueLabel.horizontalAlignmentMode = .center
        hudNode.addChild(scoreValueLabel)

        // Preview (moved to top-right)
        nextTitleLabel.name = "topTipLabel"
        nextTitleLabel.text = "下一个"
        nextTitleLabel.fontSize = DesignFonts.caption + 2
        nextTitleLabel.fontColor = DesignColors.textPrimary
        nextTitleLabel.verticalAlignmentMode = .center
        nextTitleLabel.horizontalAlignmentMode = .center
        hudNode.addChild(nextTitleLabel)

        nextPreviewTileNode.fillColor = DesignColors.card1
        nextPreviewTileNode.strokeColor = .clear
        hudNode.addChild(nextPreviewTileNode)

        nextPreviewValueLabel.fontSize = DesignFonts.previewNumber
        nextPreviewValueLabel.fontColor = DesignColors.cardTextDark
        nextPreviewValueLabel.verticalAlignmentMode = .center
        nextPreviewValueLabel.horizontalAlignmentMode = .center
        nextPreviewTileNode.addChild(nextPreviewValueLabel)

        // Simplified tips
        tipsLabel.text = "滑动合并相同数字"
        tipsLabel.fontSize = DesignFonts.caption + 2
        tipsLabel.fontColor = DesignColors.textSecondary
        tipsLabel.verticalAlignmentMode = .center
        tipsLabel.horizontalAlignmentMode = .center
        hudNode.addChild(tipsLabel)

        settlementEffectNode.zPosition = 8
        addChild(settlementEffectNode)

        // Tutorial UI
        tutorialArrowNode.zPosition = 20
        tutorialArrowNode.isHidden = true
        hudNode.addChild(tutorialArrowNode)

        tutorialInstructionLabel.fontSize = DesignFonts.body + 4
        tutorialInstructionLabel.fontColor = SKColor.white
        tutorialInstructionLabel.verticalAlignmentMode = .center
        tutorialInstructionLabel.horizontalAlignmentMode = .center
        tutorialInstructionLabel.zPosition = 20
        tutorialInstructionLabel.isHidden = true
        hudNode.addChild(tutorialInstructionLabel)

        tutorialHighlightNode.zPosition = 15
        tutorialHighlightNode.isHidden = true
        hudNode.addChild(tutorialHighlightNode)

        // Overlay
        overlayNode.zPosition = 30
        overlayNode.isHidden = true
        hudNode.addChild(overlayNode)

        overlayDimNode.fillColor = SKColor(white: 0.0, alpha: 0.35)
        overlayDimNode.strokeColor = .clear
        overlayNode.addChild(overlayDimNode)

        overlayPanelNode.fillColor = DesignColors.overlayBackground
        overlayPanelNode.strokeColor = .clear
        overlayNode.addChild(overlayPanelNode)

        overlayTitleLabel.fontSize = DesignFonts.title
        overlayTitleLabel.fontColor = DesignColors.textPrimary
        overlayTitleLabel.horizontalAlignmentMode = .center
        overlayTitleLabel.verticalAlignmentMode = .center
        overlayPanelNode.addChild(overlayTitleLabel)

        overlayPanelNode.addChild(overlayContentNode)

        overlayCloseNode.name = "overlayClose"
        overlayCloseNode.fillColor = DesignColors.primaryButton
        overlayCloseNode.strokeColor = .clear
        overlayPanelNode.addChild(overlayCloseNode)

        overlayCloseLabel.text = "关闭"
        overlayCloseLabel.fontSize = DesignFonts.button
        overlayCloseLabel.fontColor = .white
        overlayCloseLabel.verticalAlignmentMode = .center
        overlayCloseLabel.horizontalAlignmentMode = .center
        overlayCloseNode.addChild(overlayCloseLabel)
    }

    private func installInput(on view: SKView) {
        guard inputController == nil else { return }
        let controller = InputController(view: view)
        controller.onSwipe = { [weak self] direction in
            self?.handleSwipe(direction)
        }
        inputController = controller
    }

    private func startNewGame(isTutorial: Bool = false) {
        model.reset()
        spawner.reset(for: model.board)
        hasSubmittedCurrentGame = false
        scenePhase = .playing
        settlementSteps = []
        settlementStepIndex = 0
        settlementRunningTotal = 0
        settlementCurrentValue = 0
        settlementEffectNode.removeAllChildren()
        hideOverlay()
        hideTutorialUI()

        // Reset score tracking
        previousScore = 0
        consecutiveMerges = 0
        scoreValueLabel.text = "0"

        if isTutorial {
            startTutorial()
        } else {
            let initialCount = 5  // Fewer starting tiles for easier game
            for _ in 0..<initialCount {
                guard let position = model.emptyPositions.randomElement() else { break }
                _ = model.place(spawner.takePreviewTile(), at: position)
                spawner.refreshPreview(for: model.board)
            }
            updateHUD()
            rebuildTileNodes(popAt: [])
        }
    }

    // MARK: - Tutorial

    private func startTutorial() {
        tutorialPhase = .welcome
        setupTutorialWelcome()
    }

    private func setupTutorialWelcome() {
        // 预设教程初始布局
        // 棋盘:
        // .  .  .  .
        // .  1  2  .
        // .  .  .  .
        // .  .  .  .
        // 下一张是 3

        model.reset()
        _ = model.place(Tile(1), at: GridPosition(row: 1, col: 1))
        _ = model.place(Tile(2), at: GridPosition(row: 1, col: 2))

        // 设置下一个为 3
        spawner.forcePreview(value: 3)

        rebuildTileNodes(popAt: [])

        // 显示欢迎信息和箭头
        showTutorialArrow(direction: .right, at: GridPosition(row: 1, col: 3))
        showTutorialInstruction("欢迎！向右滑动合并 1 和 2")
    }

    private func setupTutorialStep1() {
        // 1+2=3 完成后，设置下一步
        // 棋盘:
        // .  .  .  .
        // .  .  .  3
        // .  .  .  .
        // .  .  .  .
        // 下一张是 3

        // 清除之前的 tile
        model.reset()
        _ = model.place(Tile(3), at: GridPosition(row: 1, col: 3))

        // 在左边放一个 3，演示 3+3=6
        _ = model.place(Tile(3), at: GridPosition(row: 1, col: 2))

        spawner.forcePreview(value: 3)

        rebuildTileNodes(popAt: [])

        tutorialPhase = .step2Merge33
        showTutorialArrow(direction: .right, at: GridPosition(row: 1, col: 3))
        showTutorialInstruction("相同数字合并！向右滑动")
    }

    private func setupTutorialStep2() {
        // 3+3=6 完成后，进入自由游戏
        tutorialPhase = .step3FreePlay
        hideTutorialUI()

        // 继续正常游戏，添加更多 tiles
        let initialCount = 4
        for _ in 0..<initialCount {
            guard let position = model.emptyPositions.randomElement() else { break }
            _ = model.place(spawner.takePreviewTile(), at: position)
            spawner.refreshPreview(for: model.board)
        }

        updateHUD()
        rebuildTileNodes(popAt: [])

        // 显示完成信息
        showTutorialInstruction("很好！你学会了！")
        run(.wait(forDuration: 1.5)) { [weak self] in
            self?.hideTutorialUI()
            self?.tutorialPhase = .none
            // 保存完成状态
            UserDefaults.standard.set(true, forKey: "hasSeenTutorial")
        }
    }

    private func showTutorialArrow(direction: MoveDirection, at position: GridPosition) {
        tutorialArrowNode.isHidden = false

        let board = boardFrame()
        let pos = point(for: position)
        let metrics = boardMetrics()

        // Arrow position: next to the specified position
        let arrowOffset: CGFloat = metrics.tileSide * 0.8
        var arrowPos = pos
        switch direction {
        case .right:
            arrowPos.x += arrowOffset
        case .left:
            arrowPos.x -= arrowOffset
        case .up:
            arrowPos.y += arrowOffset
        case .down:
            arrowPos.y -= arrowOffset
        }

        // Create arrow shape
        let arrowPath = CGMutablePath()
        let arrowSize: CGFloat = 20
        switch direction {
        case .right:
            arrowPath.move(to: CGPoint(x: -arrowSize, y: -arrowSize * 0.5))
            arrowPath.addLine(to: CGPoint(x: arrowSize * 0.5, y: 0))
            arrowPath.addLine(to: CGPoint(x: -arrowSize, y: arrowSize * 0.5))
        case .left:
            arrowPath.move(to: CGPoint(x: arrowSize, y: -arrowSize * 0.5))
            arrowPath.addLine(to: CGPoint(x: -arrowSize * 0.5, y: 0))
            arrowPath.addLine(to: CGPoint(x: arrowSize, y: arrowSize * 0.5))
        case .up:
            arrowPath.move(to: CGPoint(x: -arrowSize * 0.5, y: -arrowSize))
            arrowPath.addLine(to: CGPoint(x: 0, y: arrowSize * 0.5))
            arrowPath.addLine(to: CGPoint(x: arrowSize * 0.5, y: -arrowSize))
        case .down:
            arrowPath.move(to: CGPoint(x: -arrowSize * 0.5, y: arrowSize))
            arrowPath.addLine(to: CGPoint(x: 0, y: -arrowSize * 0.5))
            arrowPath.addLine(to: CGPoint(x: arrowSize * 0.5, y: arrowSize))
        }
        arrowPath.closeSubpath()

        tutorialArrowNode.path = arrowPath
        tutorialArrowNode.fillColor = DesignColors.highlight
        tutorialArrowNode.strokeColor = .clear
        tutorialArrowNode.position = arrowPos
        tutorialArrowNode.removeAllActions()
        tutorialArrowNode.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.move(by: CGVector(dx: 0, dy: -8), duration: 0.4),
            SKAction.move(by: CGVector(dx: 0, dy: 8), duration: 0.4)
        ])))
    }

    private func showTutorialInstruction(_ text: String) {
        tutorialInstructionLabel.isHidden = false
        tutorialInstructionLabel.text = text
        tutorialInstructionLabel.position = CGPoint(x: size.width * 0.5, y: size.height * 0.25)
        tutorialInstructionLabel.removeAllActions()
        tutorialInstructionLabel.alpha = 1
    }

    private func hideTutorialUI() {
        tutorialArrowNode.isHidden = true
        tutorialInstructionLabel.isHidden = true
        tutorialHighlightNode.isHidden = true
    }

    private func handleTutorialMove(_ direction: MoveDirection) -> Bool {
        guard tutorialPhase != .none else { return false }

        let result = model.move(direction)
        guard result.didMove else { return true }

        isAnimatingMove = true
        animateMovements(result.movements) { [weak self] in
            guard let self = self else { return }

            if self.tutorialPhase == .welcome && direction == .right {
                // 检查是否 1+2 合并成 3
                if let tile = self.model.tile(at: GridPosition(row: 1, col: 3)), tile.value == 3 {
                    self.spawnAfterMove(from: result)
                    self.setupTutorialStep1()
                }
            } else if self.tutorialPhase == .step2Merge33 && direction == .right {
                // 检查是否 3+3 合并成 6
                if let tile = self.model.tile(at: GridPosition(row: 1, col: 3)), tile.value == 6 {
                    self.spawnAfterMove(from: result)
                    self.setupTutorialStep2()
                }
            } else if self.tutorialPhase == .step3FreePlay {
                // 自由游戏模式
                self.spawnAfterMove(from: result)
            } else {
                // 其他方向，继续等待正确方向
                self.spawnAfterMove(from: result)
            }

            self.isAnimatingMove = false
        }

        return true
    }

    private func handleSwipe(_ direction: MoveDirection) {
        guard !isAnimatingMove, activeOverlay == .none else { return }

        // Tutorial mode handles moves specially
        if tutorialPhase != .none {
            if handleTutorialMove(direction) {
                return
            }
        }

        if scenePhase == .gameOverPrompt {
            beginSettlementSequence()
            return
        }

        if scenePhase == .settlement {
            return
        }

        let result = model.move(direction)
        guard result.didMove else {
            if model.isGameOver {
                enterGameOverPrompt()
            }
            return
        }

        isAnimatingMove = true
        animateMovements(result.movements) { [weak self] in
            self?.spawnAfterMove(from: result)
            self?.isAnimatingMove = false
        }
    }

    private func spawnAfterMove(from result: MoveResult) {
        var popPositions = Set(result.merges.map(\.at))
        let fallbackCandidates = model.emptyPositions
        let candidates = result.spawnCandidates.isEmpty ? fallbackCandidates : result.spawnCandidates

        if let spawnPosition = candidates.randomElement() {
            _ = model.place(spawner.takePreviewTile(), at: spawnPosition)
            spawner.refreshPreview(for: model.board)
            popPositions.insert(spawnPosition)
        }

        updateHUD()
        rebuildTileNodes(popAt: popPositions)

        if model.isGameOver {
            enterGameOverPrompt()
        }
    }

    private func animateMovements(_ movements: [TileMovement], completion: @escaping () -> Void) {
        let duration = DesignAnimation.moveDuration

        // Track merge positions and count
        var mergePositions: Set<GridPosition> = []
        var mergeCount = 0
        for movement in movements {
            if movement.consumedInMerge {
                mergePositions.insert(movement.to)
                mergeCount += 1
            }
        }

        // Track consecutive merges for combo - show combo based on THIS move
        if mergeCount >= 3 && scenePhase == .playing {
            // Show combo indicator for this move
            let board = boardFrame()
            effectsManager?.showComboIndicator(text: "Combo x\(mergeCount)!", at: CGPoint(x: size.width * 0.5, y: board.midY))
            effectsManager?.screenShake(intensity: DesignEffects.shakeIntensity * 0.5)
        }

        for movement in movements {
            guard let node = tileNodes[movement.from] else { continue }
            let moveAction = SKAction.move(to: point(for: movement.to), duration: duration)
            moveAction.timingMode = .easeInEaseOut

            if movement.consumedInMerge {
                let fadeAction = SKAction.fadeOut(withDuration: DesignAnimation.flashDuration)
                node.run(.sequence([moveAction, fadeAction]))
            } else {
                node.run(moveAction)
            }
        }

        // Play enhanced merge animation
        if !mergePositions.isEmpty {
            run(.sequence([SKAction.wait(forDuration: duration + 0.05)])) { [weak self] in
                self?.playMergeAnimation(at: mergePositions)
            }
        }

        run(.sequence([SKAction.wait(forDuration: duration + 0.02)]), completion: completion)
    }

    private func playMergeAnimation(at positions: Set<GridPosition>) {
        for position in positions {
            guard let node = tileNodes[position] else { continue }

            // Use effects manager for enhanced animation
            effectsManager?.playMergeEffect(on: node)
        }

        // Screen shake for big merges
        if positions.count >= 2 {
            effectsManager?.screenShake(intensity: DesignEffects.shakeIntensity * 0.3)
        }
    }

    private func layoutScene() {
        updateBoardLayoutCache()
        drawBoardBackground()

        let safeTopInset = view?.safeAreaInsets.top ?? 0
        let safeBottomInset = view?.safeAreaInsets.bottom ?? 0
        let board = boardFrame()

        // Top bar position - keep it simple
        let topBarY = board.maxY + 40

        // Menu button (left)
        let buttonSize = CGSize(width: 50, height: 36)
        menuButtonNode.path = CGPath(roundedRect: CGRect(
            x: -buttonSize.width * 0.5,
            y: -buttonSize.height * 0.5,
            width: buttonSize.width,
            height: buttonSize.height
        ), cornerWidth: 8, cornerHeight: 8, transform: nil)
        menuButtonNode.position = CGPoint(x: 25 + buttonSize.width * 0.5, y: topBarY)
        menuTextLabel.isHidden = true

        // Stats button (right)
        statsButtonNode.path = menuButtonNode.path
        statsButtonNode.position = CGPoint(x: size.width - 25 - buttonSize.width * 0.5, y: topBarY)
        statsTextLabel.isHidden = true

        // Preview tile - put it ABOVE the board, centered (traditional position)
        let metrics = boardMetrics()
        let previewSide = metrics.tileSide * 0.75
        nextTitleLabel.text = "下一个"
        nextTitleLabel.fontSize = 12
        nextTitleLabel.fontColor = DesignColors.textSecondary

        // Center preview above board
        nextTitleLabel.position = CGPoint(x: size.width * 0.5, y: topBarY + 20)
        nextPreviewTileNode.path = CGPath(roundedRect: CGRect(
            x: -previewSide * 0.5,
            y: -previewSide * 0.5,
            width: previewSide,
            height: previewSide
        ), cornerWidth: metrics.cornerRadius * 0.6, cornerHeight: metrics.cornerRadius * 0.6, transform: nil)
        nextPreviewTileNode.position = CGPoint(x: size.width * 0.5, y: topBarY - 4)
        nextPreviewValueLabel.position = CGPoint(x: 0, y: 0)

        // Hide score labels (not showing in top bar)
        scoreLabel.isHidden = true
        scoreValueLabel.isHidden = true

        // Bottom tip
        tipsLabel.position = CGPoint(x: size.width * 0.5, y: max(safeBottomInset + 12, board.minY - 24))
        tipsLabel.fontSize = 10

        // Overlay - centered with new design
        overlayDimNode.path = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
        let panelWidth: CGFloat = 260
        let panelHeight: CGFloat = 340
        let panelSize = CGSize(width: panelWidth, height: panelHeight)
        overlayPanelNode.path = CGPath(roundedRect: CGRect(
            x: -panelSize.width * 0.5,
            y: -panelSize.height * 0.5,
            width: panelSize.width,
            height: panelSize.height
        ), cornerWidth: 20, cornerHeight: 20, transform: nil)
        overlayPanelNode.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        overlayTitleLabel.position = CGPoint(x: 0, y: panelSize.height * 0.5 - 35)
        overlayContentNode.position = CGPoint(x: 0, y: 10)

        let closeSize = CGSize(width: 44, height: 28)
        overlayCloseNode.path = CGPath(roundedRect: CGRect(
            x: -closeSize.width * 0.5,
            y: -closeSize.height * 0.5,
            width: closeSize.width,
            height: closeSize.height
        ), cornerWidth: 6, cornerHeight: 6, transform: nil)
        overlayCloseNode.position = CGPoint(x: 0, y: -panelSize.height * 0.5 + 20)
    }

    private func drawBoardBackground() {
        boardNode.removeAllChildren()
        let boardRect = boardFrame()
        let metrics = boardMetrics()

        // Board base with new color
        let base = SKShapeNode(
            rect: boardRect,
            cornerRadius: metrics.cornerRadius
        )
        base.fillColor = DesignColors.boardBase
        base.strokeColor = .clear
        boardNode.addChild(base)

        // Cell backgrounds with new color
        for row in 0..<GameModel.boardSize {
            for col in 0..<GameModel.boardSize {
                let cell = SKShapeNode(
                    rectOf: CGSize(width: metrics.tileSide, height: metrics.tileSide),
                    cornerRadius: metrics.cornerRadius * 0.6
                )
                cell.fillColor = DesignColors.cellFill
                cell.strokeColor = .clear
                cell.position = point(for: GridPosition(row: row, col: col))
                boardNode.addChild(cell)
            }
        }
    }

    private func rebuildTileNodes(popAt positions: Set<GridPosition>) {
        tileLayerNode.removeAllChildren()
        tileNodes.removeAll()

        for row in 0..<GameModel.boardSize {
            for col in 0..<GameModel.boardSize {
                let position = GridPosition(row: row, col: col)
                guard let tile = model.tile(at: position) else { continue }
                let node = makeTileNode(for: tile, at: position)
                tileLayerNode.addChild(node)
                tileNodes[position] = node

                if positions.contains(position) {
                    effectsManager?.playSpawnEffect(on: node)
                }
            }
        }
    }

    private func makeTileNode(for tile: Tile, at position: GridPosition) -> SKShapeNode {
        let metrics = boardMetrics()
        let node = SKShapeNode(
            rectOf: CGSize(width: metrics.tileSide, height: metrics.tileSide),
            cornerRadius: metrics.cornerRadius * 0.6
        )
        node.fillColor = DesignColors.cardColor(for: tile.value)
        node.strokeColor = .clear
        node.position = point(for: position)

        // Enhanced label with better font sizing
        let label = SKLabelNode(fontNamed: DesignFonts.fontName)
        label.text = "\(tile.value)"
        label.fontSize = DesignFonts.cardFontSize(for: tile.value)
        label.fontColor = DesignColors.cardTextColor(for: tile.value)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        node.addChild(label)

        // Add subtle glow for high-value cards
        if tile.value >= 24 {
            addGlowToTile(node, value: tile.value)
        }

        return node
    }

    private func addGlowToTile(_ node: SKShapeNode, value: Int) {
        // Subtle inner highlight for premium cards
        let highlight = SKShapeNode(rectOf: CGSize(width: 80, height: 4))
        highlight.fillColor = SKColor.white.withAlphaComponent(0.15)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: 0, y: (boardMetrics().tileSide - 8) * 0.3)
        node.addChild(highlight)
    }

    private func updateHUD() {
        let board = boardFrame()
        let topBarY = board.maxY + 40

        // Update preview
        let nextValue = spawner.previewTile.value
        nextPreviewValueLabel.text = "\(nextValue)"
        nextPreviewValueLabel.fontSize = DesignFonts.previewFontSize(for: nextValue)
        nextPreviewValueLabel.fontColor = DesignColors.cardTextColor(for: nextValue)
        nextPreviewTileNode.fillColor = DesignColors.cardColor(for: nextValue)

        // Update visibility based on phase
        switch scenePhase {
        case .playing:
            menuButtonNode.isHidden = false
            statsButtonNode.isHidden = false
            nextPreviewTileNode.isHidden = false
            nextTitleLabel.isHidden = false
            nextTitleLabel.text = "下一个"
            nextTitleLabel.fontSize = 12
            nextTitleLabel.fontColor = DesignColors.textSecondary
            // Preview position
            let previewSide = boardMetrics().tileSide * 0.75
            nextTitleLabel.position = CGPoint(x: size.width * 0.5, y: topBarY + 20)
            nextPreviewTileNode.position = CGPoint(x: size.width * 0.5, y: topBarY - 4)

        case .gameOverPrompt:
            menuButtonNode.isHidden = true
            statsButtonNode.isHidden = true
            nextPreviewTileNode.isHidden = true
            nextTitleLabel.isHidden = false
            nextTitleLabel.text = "游戏结束"
            nextTitleLabel.fontSize = 24
            nextTitleLabel.fontColor = DesignColors.textSecondary
            nextTitleLabel.position = CGPoint(x: size.width * 0.5, y: topBarY)

        case .settlement:
            menuButtonNode.isHidden = true
            statsButtonNode.isHidden = true
            nextPreviewTileNode.isHidden = true
            nextTitleLabel.isHidden = false
            nextTitleLabel.text = "\(settlementRunningTotal)"
            nextTitleLabel.fontSize = 36
            nextTitleLabel.fontColor = settlementColor(for: settlementCurrentValue)
            nextTitleLabel.position = CGPoint(x: size.width * 0.5, y: topBarY)
        }

        updateTopBarVisibility()
        tipsLabel.text = bottomTipText()

        if activeOverlay == .stats {
            refreshStatsOverlay()
        }
    }

    private func boardMetrics() -> (tileSide: CGFloat, spacing: CGFloat, cornerRadius: CGFloat) {
        cachedBoardMetrics
    }

    private func boardFrame() -> CGRect {
        cachedBoardFrame
    }

    private func updateBoardLayoutCache() {
        let shortest = min(size.width, size.height)
        let tileSide = max(52, shortest * 0.16)
        let spacing = tileSide * 0.12
        let cornerRadius = tileSide * 0.14
        cachedBoardMetrics = (tileSide, spacing, cornerRadius)

        let n = CGFloat(GameModel.boardSize)
        let boardLength = tileSide * n + spacing * (n + 1)
        let x = (size.width - boardLength) * 0.5
        let safeTopInset = view?.safeAreaInsets.top ?? 0
        let safeBottomInset = view?.safeAreaInsets.bottom ?? 0
        let topReserved = safeTopInset + 130
        let bottomReserved = safeBottomInset + 88
        let availableHeight = max(boardLength, size.height - topReserved - bottomReserved)
        let y = bottomReserved + (availableHeight - boardLength) * 0.5
        cachedBoardFrame = CGRect(x: x, y: y, width: boardLength, height: boardLength)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        if activeOverlay != .none {
            // Handle menu overlay button taps
            if activeOverlay == .menu {
                if let tappedButton = findTappedMenuButton(at: location) {
                    handleMenuButtonTap(tappedButton)
                    return
                }
            }

            if didTapNode(named: "overlayClose", at: location) || !overlayPanelNode.contains(location) {
                hideOverlay()
            }
            return
        }

        if scenePhase == .gameOverPrompt {
            beginSettlementSequence()
            return
        }

        if scenePhase == .settlement {
            startNewGame()
            return
        }

        if didTapNode(named: "menuButton", at: location) {
            effectsManager?.playButtonTap(on: menuButtonNode)
            showOverlay(.menu)
            return
        }

        if didTapNode(named: "statsButton", at: location) {
            effectsManager?.playButtonTap(on: statsButtonNode)
            showOverlay(.stats)
        }
    }

    private func findTappedMenuButton(at location: CGPoint) -> Int? {
        for node in nodes(at: location) {
            if let name = node.name, name.hasPrefix("menuButton_") {
                let tagStr = name.replacingOccurrences(of: "menuButton_", with: "")
                return Int(tagStr)
            }
        }
        return nil
    }

    private func handleMenuButtonTap(_ tag: Int) {
        hideOverlay()
        switch tag {
        case 1:
            // 继续游戏 - just close overlay
            break
        case 2:
            // 重新开始
            startNewGame()
        case 3:
            // 返回主界面 - same as restart for now
            startNewGame()
        default:
            break
        }
    }

    private func didTapNode(named nodeName: String, at location: CGPoint) -> Bool {
        for node in nodes(at: location) {
            var current: SKNode? = node
            while let checking = current {
                if checking.name == nodeName {
                    return true
                }
                current = checking.parent
            }
        }
        return false
    }

    private func showOverlay(_ page: OverlayPage) {
        activeOverlay = page
        overlayNode.isHidden = false
        overlayContentNode.removeAllChildren()

        switch page {
        case .none:
            hideOverlay()
        case .menu:
            showNewMenuOverlay()
        case .stats:
            showNewStatsOverlay()
        }
        nextTitleLabel.text = topTipText()
    }

    // MARK: - New Menu Design

    private func showNewMenuOverlay() {
        overlayTitleLabel.text = "TriYan"
        overlayTitleLabel.fontSize = 36
        overlayTitleLabel.fontColor = DesignColors.textPrimary
        overlayCloseNode.isHidden = true

        // Play button
        createNewMenuButton(title: "继续游戏", icon: "▶", tag: 1, color: DesignColors.card6)
        // Restart button
        createNewMenuButton(title: "重新开始", icon: "↺", tag: 2, color: DesignColors.card12)

        // Subtitle
        let subtitle = SKLabelNode(fontNamed: DesignFonts.fontNameMedium)
        subtitle.text = "滑动合并，挑战高分"
        subtitle.fontSize = 14
        subtitle.fontColor = DesignColors.textSecondary
        subtitle.position = CGPoint(x: 0, y: -90)
        overlayContentNode.addChild(subtitle)
    }

    private func createNewMenuButton(title: String, icon: String, tag: Int, color: SKColor) {
        let buttonWidth: CGFloat = 200
        let buttonHeight: CGFloat = 56

        // Button background
        let button = SKShapeNode()
        button.path = CGPath(roundedRect: CGRect(
            x: -buttonWidth * 0.5,
            y: -buttonHeight * 0.5,
            width: buttonWidth,
            height: buttonHeight
        ), cornerWidth: 14, cornerHeight: 14, transform: nil)
        button.fillColor = color
        button.strokeColor = .clear
        button.name = "menuButton_\(tag)"
        button.zPosition = 1

        // Icon
        let iconLabel = SKLabelNode(fontNamed: DesignFonts.fontName)
        iconLabel.text = icon
        iconLabel.fontSize = 22
        iconLabel.fontColor = .white
        iconLabel.position = CGPoint(x: -buttonWidth * 0.3, y: 0)
        iconLabel.verticalAlignmentMode = .center
        button.addChild(iconLabel)

        // Title
        let titleLabel = SKLabelNode(fontNamed: DesignFonts.fontName)
        titleLabel.text = title
        titleLabel.fontSize = 18
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 10, y: 0)
        titleLabel.verticalAlignmentMode = .center
        button.addChild(titleLabel)

        // Position
        let yOffset = CGFloat(1 - tag) * 72
        button.position = CGPoint(x: 0, y: yOffset)
        overlayContentNode.addChild(button)
    }

    // MARK: - New Stats Design

    private func showNewStatsOverlay() {
        overlayTitleLabel.text = "统计"
        overlayTitleLabel.fontSize = 28
        overlayTitleLabel.fontColor = DesignColors.textPrimary
        overlayCloseNode.isHidden = false

        let bestScore = UserDefaults.standard.integer(forKey: "bestScore")
        let resultScore = model.threesStyleResult()
        let statsSnapshot = statsStore.snapshot()

        // Create stat cards
        // Best Score Card
        createStatCard(title: "最高分", value: "\(bestScore)", color: DesignColors.card3, yOffset: 60)
        // Current Score Card
        createStatCard(title: "本局", value: "\(resultScore)", color: DesignColors.card6, yOffset: -10)
        // Games Played Card
        createStatCard(title: "总局数", value: "\(statsSnapshot.gamesPlayed)", color: DesignColors.card12, yOffset: -80)

        // Top scores
        if !statsSnapshot.topScores.isEmpty {
            let topLabel = SKLabelNode(fontNamed: DesignFonts.fontNameMedium)
            topLabel.text = "Top Scores"
            topLabel.fontSize = 14
            topLabel.fontColor = DesignColors.textSecondary
            topLabel.position = CGPoint(x: 0, y: -115)
            overlayContentNode.addChild(topLabel)

            let topScoreLabel = SKLabelNode(fontNamed: DesignFonts.fontName)
            topScoreLabel.text = statsSnapshot.topScores.prefix(3).map { "\($0)" }.joined(separator: "  ")
            topScoreLabel.fontSize = 16
            topScoreLabel.fontColor = DesignColors.textPrimary
            topScoreLabel.position = CGPoint(x: 0, y: -135)
            overlayContentNode.addChild(topScoreLabel)
        }
    }

    private func createStatCard(title: String, value: String, color: SKColor, yOffset: CGFloat) {
        let cardWidth: CGFloat = 180
        let cardHeight: CGFloat = 50

        // Card background
        let card = SKShapeNode()
        card.path = CGPath(roundedRect: CGRect(
            x: -cardWidth * 0.5,
            y: -cardHeight * 0.5,
            width: cardWidth,
            height: cardHeight
        ), cornerWidth: 10, cornerHeight: 10, transform: nil)
        card.fillColor = color
        card.strokeColor = .clear
        card.position = CGPoint(x: 0, y: yOffset)
        overlayContentNode.addChild(card)

        // Title
        let titleLabel = SKLabelNode(fontNamed: DesignFonts.fontNameMedium)
        titleLabel.text = title
        titleLabel.fontSize = 12
        titleLabel.fontColor = SKColor.white.withAlphaComponent(0.8)
        titleLabel.position = CGPoint(x: -cardWidth * 0.3, y: 8)
        titleLabel.verticalAlignmentMode = .center
        card.addChild(titleLabel)

        // Value
        let valueLabel = SKLabelNode(fontNamed: DesignFonts.fontNameHeavy)
        valueLabel.text = value
        valueLabel.fontSize = 24
        valueLabel.fontColor = .white
        valueLabel.position = CGPoint(x: -cardWidth * 0.3, y: -10)
        valueLabel.verticalAlignmentMode = .center
        card.addChild(valueLabel)
    }

    private func hideOverlay() {
        activeOverlay = .none
        overlayNode.isHidden = true
        overlayContentNode.removeAllChildren()
        nextTitleLabel.text = topTipText()

        // Reset close button text
        overlayCloseLabel.text = "关闭"
    }

    // Legacy function - kept for compatibility
    private func refreshStatsOverlay() {
        // Now handled by showNewStatsOverlay
    }

    private func enterGameOverPrompt() {
        guard scenePhase == .playing else { return }
        scenePhase = .gameOverPrompt
        settlementEffectNode.removeAllChildren()

        // Apply game over visual effect
        let nodes = Array(tileNodes.values)
        effectsManager?.applyGameOverStyle(to: nodes)
        effectsManager?.screenShake(intensity: DesignEffects.shakeIntensity)

        updateHUD()
    }

    private func beginSettlementSequence() {
        guard scenePhase == .gameOverPrompt else { return }
        scenePhase = .settlement
        settlementSteps = model.tileHistogramFromThree().filter { $0.count > 0 }
        settlementStepIndex = 0
        settlementRunningTotal = 0
        settlementCurrentValue = 0
        submitCurrentScore()
        applySettlementNumberStyle()
        updateHUD()
        runSettlementStep()
    }

    private func runSettlementStep() {
        guard settlementStepIndex < settlementSteps.count else {
            for node in tileNodes.values {
                node.alpha = 1.0
            }
            updateHUD()
            return
        }

        let step = settlementSteps[settlementStepIndex]
        settlementCurrentValue = step.value
        let perTileScore = model.scoreForTileValue(step.value)
        let stepScore = step.count * perTileScore
        settlementRunningTotal += stepScore
        nextTitleLabel.text = "\(settlementRunningTotal)"
        nextTitleLabel.fontColor = settlementColor(for: step.value)

        for row in 0..<GameModel.boardSize {
            for col in 0..<GameModel.boardSize {
                let position = GridPosition(row: row, col: col)
                guard let node = tileNodes[position], let tile = model.tile(at: position) else { continue }
                if tile.value == step.value {
                    node.alpha = 1.0
                    if perTileScore > 0 {
                        addBonusLabel("+\(perTileScore)", at: node.position, stepValue: step.value)
                    }
                } else {
                    node.alpha = 0.35
                }
            }
        }

        settlementStepIndex += 1
        let wait = SKAction.wait(forDuration: 1.2)
        run(wait) { [weak self] in
            self?.runSettlementStep()
        }
    }

    private func addBonusLabel(_ text: String, at position: CGPoint, stepValue: Int) {
        // Use effects manager for flying bonus animation
        _ = effectsManager?.createFlyingBonus(
            text: text,
            at: CGPoint(x: position.x, y: position.y + 28),
            color: settlementColor(for: stepValue)
        )
    }

    private func applySettlementNumberStyle() {
        for node in tileNodes.values {
            for child in node.children {
                if let label = child as? SKLabelNode {
                    label.fontColor = softScoreColor
                }
            }
        }
    }

    private func populateOverlayLines(_ lines: [String]) {
        overlayContentNode.removeAllChildren()
        // Limit to first 15 lines to prevent overflow
        let maxLines = 15
        let displayLines = Array(lines.prefix(maxLines))
        let lineSpacing: CGFloat = 24  // Smaller spacing
        let startY = CGFloat(displayLines.count - 1) * lineSpacing * 0.5

        for (index, line) in displayLines.enumerated() {
            let label = SKLabelNode(fontNamed: DesignFonts.fontNameMedium)
            label.text = line
            label.fontSize = 14  // Smaller font
            label.fontColor = line.contains("分") ? softScoreColor : DesignColors.textPrimary
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: startY - CGFloat(index) * lineSpacing)
            overlayContentNode.addChild(label)
        }
    }

    private func submitCurrentScore() {
        guard !hasSubmittedCurrentGame else { return }
        let defaults = UserDefaults.standard
        let currentResult = model.threesStyleResult()
        let histogram = model.tileHistogramFromThree().filter { $0.count > 0 }
        let bestScore = defaults.integer(forKey: "bestScore")

        // Check for new record
        let isNewRecord = currentResult > bestScore
        if isNewRecord {
            defaults.set(currentResult, forKey: "bestScore")
            // Play new record effect after settlement completes
            run(.wait(forDuration: 3.0)) { [weak self] in
                self?.effectsManager?.playNewRecordEffect()
            }
        }

        statsStore.recordGame(resultScore: currentResult, histogram: histogram)
        gameCenterService.submitScore(currentResult)

        let snapshot = statsStore.snapshot()
        gameCenterService.reportAchievementProgress(
            makeAchievementProgress(
                resultScore: currentResult,
                maxTileEver: snapshot.maxTileEver,
                gamesPlayed: snapshot.gamesPlayed,
                tile3Count: statsStore.lifetimeCount(for: 3)
            )
        )

        loadGlobalLeaderboardIfNeeded()
        hasSubmittedCurrentGame = true
    }

    private func loadGlobalLeaderboardIfNeeded() {
        guard gameCenterService.isAuthenticated else {
            globalLeaderboardEntries = []
            isLoadingGlobalLeaderboard = false
            return
        }
        guard !isLoadingGlobalLeaderboard else { return }
        isLoadingGlobalLeaderboard = true
        gameCenterService.loadGlobalLeaderboardTop(limit: 10) { [weak self] entries in
            DispatchQueue.main.async {
                guard let self else { return }
                self.globalLeaderboardEntries = entries
                self.isLoadingGlobalLeaderboard = false
                if self.activeOverlay == .stats {
                    self.refreshStatsOverlay()
                }
            }
        }
    }

    private func makeAchievementProgress(
        resultScore: Int,
        maxTileEver: Int,
        gamesPlayed: Int,
        tile3Count: Int
    ) -> [GameAchievementKey: Double] {
        func percent(current: Int, target: Int) -> Double {
            guard target > 0 else { return 0 }
            return min(100.0, (Double(current) / Double(target)) * 100.0)
        }

        return [
            .score100: percent(current: resultScore, target: 100),
            .score500: percent(current: resultScore, target: 500),
            .score1500: percent(current: resultScore, target: 1500),
            .score3000: percent(current: resultScore, target: 3000),
            .maxTile24: percent(current: maxTileEver, target: 24),
            .maxTile48: percent(current: maxTileEver, target: 48),
            .maxTile96: percent(current: maxTileEver, target: 96),
            .gamesPlayed10: percent(current: gamesPlayed, target: 10),
            .gamesPlayed50: percent(current: gamesPlayed, target: 50),
            .tile3Count100: percent(current: tile3Count, target: 100)
        ]
    }

    private func topTipText() -> String {
        if scenePhase == .gameOverPrompt {
            return "动不了了!"
        }
        if scenePhase == .settlement {
            return "\(settlementRunningTotal)"
        }
        return "下一个"
    }

    private func updateTopBarVisibility() {
        // Visibility is handled in updateHUD based on scenePhase
    }

    private func bottomTipText() -> String {
        switch scenePhase {
        case .playing:
            return "滑动合并相同数字"
        case .gameOverPrompt:
            return "滑动查看分数"
        case .settlement:
            return "点击再来一局"
        }
    }

    private func settlementColor(for value: Int) -> SKColor {
        switch value {
        case ..<6:
            return SKColor(red: 0.43, green: 0.48, blue: 0.56, alpha: 1.0)
        case 6..<24:
            return SKColor(red: 0.38, green: 0.44, blue: 0.53, alpha: 1.0)
        case 24..<96:
            return SKColor(red: 0.34, green: 0.40, blue: 0.49, alpha: 1.0)
        default:
            return SKColor(red: 0.30, green: 0.36, blue: 0.45, alpha: 1.0)
        }
    }

    private func point(for position: GridPosition) -> CGPoint {
        let metrics = boardMetrics()
        let board = boardFrame()

        let x = board.minX + metrics.spacing + metrics.tileSide * 0.5 + CGFloat(position.col) * (metrics.tileSide + metrics.spacing)
        let yFromTop = metrics.spacing + metrics.tileSide * 0.5 + CGFloat(position.row) * (metrics.tileSide + metrics.spacing)
        let y = board.maxY - yFromTop
        return CGPoint(x: x, y: y)
    }

    // MARK: - Color Helper (Legacy - now uses DesignColors)

    // Kept for backward compatibility, now delegates to DesignColors
    private func color(for value: Int) -> SKColor {
        DesignColors.cardColor(for: value)
    }
}
