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

    private let model = GameModel()
    private let spawner = Spawner()
    private let statsStore = StatsStore.shared
    private let gameCenterService = GameCenterService.shared

    private var inputController: InputController?
    private var tileNodes: [GridPosition: SKShapeNode] = [:]
    private var isAnimatingMove = false
    private var hasStartedGame = false

    private let boardNode = SKNode()
    private let tileLayerNode = SKNode()
    private let hudNode = SKNode()
    private let menuButtonNode = SKShapeNode()
    private let menuIconLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let menuTextLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let statsButtonNode = SKShapeNode()
    private let statsIconLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let statsTextLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let nextTitleLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let nextPreviewTileNode = SKShapeNode()
    private let nextPreviewValueLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let tipsLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")

    private let overlayNode = SKNode()
    private let overlayDimNode = SKShapeNode()
    private let overlayPanelNode = SKShapeNode()
    private let overlayTitleLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let overlayContentNode = SKNode()
    private let overlayCloseNode = SKShapeNode()
    private let overlayCloseLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
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

    override func didMove(to view: SKView) {
        if boardNode.parent == nil {
            backgroundColor = SKColor(red: 0.98, green: 0.96, blue: 0.91, alpha: 1.0)
            addChild(boardNode)
            addChild(tileLayerNode)
            addChild(hudNode)
            configureHUD()
            installInput(on: view)
        }

        layoutScene()

        if !hasStartedGame {
            startNewGame()
            hasStartedGame = true
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutScene()
        rebuildTileNodes(popAt: [])
    }

    private func configureHUD() {
        menuButtonNode.name = "menuButton"
        menuButtonNode.fillColor = SKColor(red: 0.47, green: 0.50, blue: 0.59, alpha: 1.0)
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
        menuTextLabel.fontSize = 12
        menuTextLabel.fontColor = SKColor.darkGray
        menuTextLabel.verticalAlignmentMode = .center
        menuTextLabel.horizontalAlignmentMode = .center
        menuTextLabel.position = CGPoint(x: 0, y: -40)
        menuButtonNode.addChild(menuTextLabel)

        statsButtonNode.name = "statsButton"
        statsButtonNode.fillColor = SKColor(red: 0.47, green: 0.50, blue: 0.59, alpha: 1.0)
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
        statsTextLabel.fontSize = 12
        statsTextLabel.fontColor = SKColor.darkGray
        statsTextLabel.verticalAlignmentMode = .center
        statsTextLabel.horizontalAlignmentMode = .center
        statsTextLabel.position = CGPoint(x: 0, y: -40)
        statsButtonNode.addChild(statsTextLabel)

        nextTitleLabel.name = "topTipLabel"
        nextTitleLabel.text = "下一个"
        nextTitleLabel.fontSize = 30
        nextTitleLabel.fontColor = SKColor.darkGray
        nextTitleLabel.verticalAlignmentMode = .center
        nextTitleLabel.horizontalAlignmentMode = .center
        hudNode.addChild(nextTitleLabel)

        nextPreviewTileNode.fillColor = color(for: 1)
        nextPreviewTileNode.strokeColor = .clear
        hudNode.addChild(nextPreviewTileNode)

        nextPreviewValueLabel.fontSize = 32
        nextPreviewValueLabel.fontColor = SKColor.darkGray
        nextPreviewValueLabel.verticalAlignmentMode = .center
        nextPreviewValueLabel.horizontalAlignmentMode = .center
        nextPreviewTileNode.addChild(nextPreviewValueLabel)

        tipsLabel.text = "棋盘填满且无法移动卡牌时游戏就结束了"
        tipsLabel.fontSize = 15
        tipsLabel.fontColor = SKColor(red: 0.45, green: 0.48, blue: 0.55, alpha: 1.0)
        tipsLabel.verticalAlignmentMode = .center
        tipsLabel.horizontalAlignmentMode = .center
        hudNode.addChild(tipsLabel)

        settlementEffectNode.zPosition = 8
        addChild(settlementEffectNode)

        overlayNode.zPosition = 30
        overlayNode.isHidden = true
        hudNode.addChild(overlayNode)

        overlayDimNode.fillColor = SKColor(white: 0.0, alpha: 0.35)
        overlayDimNode.strokeColor = .clear
        overlayNode.addChild(overlayDimNode)

        overlayPanelNode.fillColor = SKColor(red: 0.95, green: 0.96, blue: 0.97, alpha: 1.0)
        overlayPanelNode.strokeColor = .clear
        overlayNode.addChild(overlayPanelNode)

        overlayTitleLabel.fontSize = 30
        overlayTitleLabel.fontColor = SKColor.darkGray
        overlayTitleLabel.horizontalAlignmentMode = .center
        overlayTitleLabel.verticalAlignmentMode = .center
        overlayPanelNode.addChild(overlayTitleLabel)

        overlayPanelNode.addChild(overlayContentNode)

        overlayCloseNode.name = "overlayClose"
        overlayCloseNode.fillColor = SKColor(red: 0.47, green: 0.50, blue: 0.59, alpha: 1.0)
        overlayCloseNode.strokeColor = .clear
        overlayPanelNode.addChild(overlayCloseNode)

        overlayCloseLabel.text = "关闭"
        overlayCloseLabel.fontSize = 14
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

    private func startNewGame() {
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

        let initialCount = 9
        for _ in 0..<initialCount {
            guard let position = model.emptyPositions.randomElement() else { break }
            _ = model.place(spawner.takePreviewTile(), at: position)
            spawner.refreshPreview(for: model.board)
        }

        updateHUD()
        rebuildTileNodes(popAt: [])
    }

    private func handleSwipe(_ direction: MoveDirection) {
        guard !isAnimatingMove, activeOverlay == .none else { return }

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
        let duration = 0.12

        for movement in movements {
            guard let node = tileNodes[movement.from] else { continue }
            let moveAction = SKAction.move(to: point(for: movement.to), duration: duration)
            moveAction.timingMode = .easeInEaseOut

            if movement.consumedInMerge {
                let fadeAction = SKAction.fadeOut(withDuration: 0.05)
                node.run(.sequence([moveAction, fadeAction]))
            } else {
                node.run(moveAction)
            }
        }

        run(.sequence([SKAction.wait(forDuration: duration + 0.02)]), completion: completion)
    }

    private func layoutScene() {
        updateBoardLayoutCache()
        drawBoardBackground()

        let safeTopInset = view?.safeAreaInsets.top ?? 0
        let safeBottomInset = view?.safeAreaInsets.bottom ?? 0
        let board = boardFrame()

        let buttonSize = CGSize(width: 92, height: 56)
        menuButtonNode.path = CGPath(roundedRect: CGRect(
            x: -buttonSize.width * 0.5,
            y: -buttonSize.height * 0.5,
            width: buttonSize.width,
            height: buttonSize.height
        ), cornerWidth: 12, cornerHeight: 12, transform: nil)
        statsButtonNode.path = menuButtonNode.path

        let metrics = boardMetrics()
        let previewSide = metrics.tileSide * 0.72
        var topBarY = board.maxY + max(buttonSize.height * 0.5, previewSide * 0.5) + 50
        var previewCenterY = topBarY
        let maxTopBarY = size.height - safeTopInset - buttonSize.height * 0.5 - 8
        if topBarY > maxTopBarY {
            let overflow = topBarY - maxTopBarY
            topBarY -= overflow
            previewCenterY -= overflow
        }

        menuButtonNode.position = CGPoint(x: 20 + buttonSize.width * 0.5, y: topBarY)
        statsButtonNode.position = CGPoint(x: size.width - 20 - buttonSize.width * 0.5, y: topBarY)

        nextTitleLabel.position = CGPoint(x: size.width * 0.5, y: topBarY - previewSide * 0.5 - 14)

        nextPreviewTileNode.path = CGPath(roundedRect: CGRect(
            x: -previewSide * 0.5,
            y: -previewSide * 0.5,
            width: previewSide,
            height: previewSide
        ), cornerWidth: metrics.cornerRadius * 0.7, cornerHeight: metrics.cornerRadius * 0.7, transform: nil)
        nextPreviewTileNode.position = CGPoint(x: size.width * 0.5, y: previewCenterY)
        nextPreviewValueLabel.position = CGPoint(x: 0, y: 0)

        tipsLabel.position = CGPoint(x: size.width * 0.5, y: max(safeBottomInset + 24, board.minY - 46))

        overlayDimNode.path = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
        let panelSize = CGSize(width: min(size.width - 40, 350), height: min(size.height - 100, 420))
        overlayPanelNode.path = CGPath(roundedRect: CGRect(
            x: -panelSize.width * 0.5,
            y: -panelSize.height * 0.5,
            width: panelSize.width,
            height: panelSize.height
        ), cornerWidth: 18, cornerHeight: 18, transform: nil)
        overlayPanelNode.position = CGPoint(x: size.width * 0.5, y: size.height * 0.52)
        overlayTitleLabel.position = CGPoint(x: 0, y: panelSize.height * 0.5 - 48)
        overlayContentNode.position = CGPoint(x: 0, y: 12)

        let closeSize = CGSize(width: 70, height: 34)
        overlayCloseNode.path = CGPath(roundedRect: CGRect(
            x: -closeSize.width * 0.5,
            y: -closeSize.height * 0.5,
            width: closeSize.width,
            height: closeSize.height
        ), cornerWidth: 10, cornerHeight: 10, transform: nil)
        overlayCloseNode.position = CGPoint(x: 0, y: -panelSize.height * 0.5 + 36)
    }

    private func drawBoardBackground() {
        boardNode.removeAllChildren()
        let boardRect = boardFrame()
        let metrics = boardMetrics()

        let base = SKShapeNode(
            rect: boardRect,
            cornerRadius: metrics.cornerRadius
        )
        base.fillColor = SKColor(red: 0.73, green: 0.68, blue: 0.62, alpha: 1.0)
        base.strokeColor = .clear
        boardNode.addChild(base)

        for row in 0..<GameModel.boardSize {
            for col in 0..<GameModel.boardSize {
                let cell = SKShapeNode(
                    rectOf: CGSize(width: metrics.tileSide, height: metrics.tileSide),
                    cornerRadius: metrics.cornerRadius * 0.6
                )
                cell.fillColor = SKColor(red: 0.82, green: 0.78, blue: 0.72, alpha: 1.0)
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
                    node.setScale(0.6)
                    node.run(SKAction.scale(to: 1.0, duration: 0.12))
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
        node.fillColor = color(for: tile.value)
        node.strokeColor = .clear
        node.position = point(for: position)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "\(tile.value)"
        label.fontSize = tile.value >= 100 ? 22 : 26
        label.fontColor = tile.value <= 3 ? SKColor.darkGray : SKColor.white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        node.addChild(label)

        return node
    }

    private func updateHUD() {
        let nextValue = spawner.previewTile.value
        nextPreviewValueLabel.text = "\(nextValue)"
        nextPreviewValueLabel.fontSize = nextValue >= 100 ? 20 : 25
        nextPreviewValueLabel.fontColor = nextValue <= 3 ? SKColor.darkGray : SKColor.white
        nextPreviewTileNode.fillColor = color(for: nextValue)
        nextTitleLabel.text = topTipText()
        let board = boardFrame()
        switch scenePhase {
        case .playing:
            let previewSide = boardMetrics().tileSide * 0.72
            let topBarY = board.maxY + max(56 * 0.5, previewSide * 0.5) + 50
            nextTitleLabel.position = CGPoint(x: size.width * 0.5, y: topBarY - previewSide * 0.5 - 14)
        case .gameOverPrompt:
            nextTitleLabel.position = CGPoint(x: size.width * 0.5, y: board.maxY + 128)
        case .settlement:
            nextTitleLabel.position = CGPoint(x: size.width * 0.5, y: board.maxY + 146)
        }
        switch scenePhase {
        case .playing:
            nextTitleLabel.fontSize = 12
            nextTitleLabel.fontColor = SKColor.darkGray
        case .gameOverPrompt:
            nextTitleLabel.fontSize = 56
            nextTitleLabel.fontColor = SKColor(red: 0.45, green: 0.48, blue: 0.55, alpha: 1.0)
        case .settlement:
            nextTitleLabel.fontSize = 66
            nextTitleLabel.fontColor = settlementColor(for: settlementCurrentValue)
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
            showOverlay(.menu)
            return
        }

        if didTapNode(named: "statsButton", at: location) {
            showOverlay(.stats)
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
            overlayTitleLabel.text = "菜单"
            populateOverlayLines([
                "继续游戏",
                "重新开始",
                "返回主界面"
            ])
        case .stats:
            overlayTitleLabel.text = "统计"
            loadGlobalLeaderboardIfNeeded()
            refreshStatsOverlay()
        }
        nextTitleLabel.text = topTipText()
    }

    private func hideOverlay() {
        activeOverlay = .none
        overlayNode.isHidden = true
        overlayContentNode.removeAllChildren()
        nextTitleLabel.text = topTipText()
    }

    private func refreshStatsOverlay() {
        var filledCount = 0
        var maxValue = 0
        let bestScore = UserDefaults.standard.integer(forKey: "bestScore")

        for row in 0..<GameModel.boardSize {
            for col in 0..<GameModel.boardSize {
                if let tile = model.tile(at: GridPosition(row: row, col: col)) {
                    filledCount += 1
                    maxValue = max(maxValue, tile.value)
                }
            }
        }

        let resultScore = model.threesStyleResult()
        let histogram = model.tileHistogramFromThree().filter { $0.count > 0 }
        let statsSnapshot = statsStore.snapshot()
        var lines = [
            "结果分: \(resultScore)",
            "当前分数: \(model.score)",
            "已占格子: \(filledCount)/\(GameModel.boardSize * GameModel.boardSize)",
            "最大数字: \(maxValue)",
            "最高分: \(bestScore)",
            "局数: \(statsSnapshot.gamesPlayed)"
        ]
        for item in histogram.prefix(3) {
            lines.append("\(item.value) x \(item.count)")
        }
        lines.append("本地TOP10")
        if statsSnapshot.topScores.isEmpty {
            lines.append("暂无记录")
        } else {
            for (index, score) in statsSnapshot.topScores.enumerated() {
                lines.append("#\(index + 1) \(score)")
            }
        }

        lines.append("数字累计")
        if statsSnapshot.lifetimeHistogram.isEmpty {
            lines.append("暂无累计")
        } else {
            for item in statsSnapshot.lifetimeHistogram.prefix(6) {
                lines.append("\(item.value) x \(item.count)")
            }
            if statsSnapshot.lifetimeHistogram.count > 6 {
                lines.append("...")
            }
        }

        lines.append("全球总榜")
        if !gameCenterService.isAuthenticated {
            lines.append("未登录 Game Center")
        } else if isLoadingGlobalLeaderboard {
            lines.append("加载中...")
        } else if globalLeaderboardEntries.isEmpty {
            lines.append("暂无数据")
        } else {
            for entry in globalLeaderboardEntries.prefix(3) {
                lines.append("#\(entry.rank) \(entry.playerName) \(entry.score)")
            }
        }
        populateOverlayLines(lines)
    }

    private func enterGameOverPrompt() {
        guard scenePhase == .playing else { return }
        scenePhase = .gameOverPrompt
        settlementEffectNode.removeAllChildren()
        for node in tileNodes.values {
            node.alpha = 1.0
        }
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
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = 32
        label.fontColor = settlementColor(for: stepValue)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: position.x, y: position.y + 28)
        settlementEffectNode.addChild(label)
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
        for (index, line) in lines.enumerated() {
            let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
            label.text = line
            label.fontSize = 22
            label.fontColor = line.contains("分") ? softScoreColor : SKColor.darkGray
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: CGFloat(lines.count - 1 - index) * 36)
            overlayContentNode.addChild(label)
        }
    }

    private func submitCurrentScore() {
        guard !hasSubmittedCurrentGame else { return }
        let defaults = UserDefaults.standard
        let currentResult = model.threesStyleResult()
        let histogram = model.tileHistogramFromThree().filter { $0.count > 0 }
        let bestScore = defaults.integer(forKey: "bestScore")
        if currentResult > bestScore {
            defaults.set(currentResult, forKey: "bestScore")
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
        let isPlaying = scenePhase == .playing
        menuButtonNode.isHidden = !isPlaying
        statsButtonNode.isHidden = !isPlaying
        nextPreviewTileNode.isHidden = !isPlaying
    }

    private func bottomTipText() -> String {
        switch scenePhase {
        case .playing:
            return "棋盘填满且无法移动卡牌时游戏就结束了"
        case .gameOverPrompt:
            return "滑动屏幕来查看你的分数"
        case .settlement:
            return "点击屏幕再来一局"
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

    private func color(for value: Int) -> SKColor {
        switch value {
        case 1:
            return SKColor(red: 0.89, green: 0.87, blue: 0.80, alpha: 1.0)
        case 2:
            return SKColor(red: 0.86, green: 0.83, blue: 0.74, alpha: 1.0)
        case 3:
            return SKColor(red: 0.95, green: 0.77, blue: 0.45, alpha: 1.0)
        case 6:
            return SKColor(red: 0.96, green: 0.64, blue: 0.34, alpha: 1.0)
        case 12:
            return SKColor(red: 0.93, green: 0.53, blue: 0.28, alpha: 1.0)
        case 24:
            return SKColor(red: 0.87, green: 0.41, blue: 0.25, alpha: 1.0)
        default:
            return SKColor(red: 0.74, green: 0.32, blue: 0.24, alpha: 1.0)
        }
    }
}
