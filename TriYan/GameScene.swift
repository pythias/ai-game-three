import UIKit
import SpriteKit

final class GameScene: SKScene {
    // MARK: - Properties

    private let model = GameModel()
    private let spawner = Spawner()
    private let statsStore = StatsStore.shared
    private let gameCenterService = GameCenterService.shared
    private let audioManager = AudioManager.shared

    private var tileNodes: [GridPosition: SKNode] = [:]
    private var tileTextureCache: [TileTextureKey: SKTexture] = [:]
    private var backgroundTextureCache: [BackgroundTextureKey: SKTexture] = [:]
    private var backgroundNode: SKSpriteNode!
    private var gridNode: SKNode!
    private var previewTileNode: SKSpriteNode?
    private var previewTileValue: Int?

    private var nextCardNode: SKShapeNode!
    private var nextTitleLabel: SKLabelNode!
    private var nextPreviewNode: SKNode!
    private var scoreCardNode: SKShapeNode!
    private var scoreTitleLabel: SKLabelNode!
    private var scoreValueLabel: SKLabelNode!
    private var bestValueLabel: SKLabelNode!
    private var menuButton: SKShapeNode!
    private var restartHudButton: SKShapeNode!
    private var hintHudButton: SKShapeNode!
    private var hintBadgeNode: SKShapeNode!
    private var hintBadgeLabel: SKLabelNode!

    private var inputController: InputController?
    private var overlayRoot: SKNode?
    private var overlayPages: [ScenePhase: SKNode] = [:]
    private var pageStack: [ScenePhase] = []
    private var infoDialogNode: SKNode?
    private var achievementToastNode: SKNode?
    private var currentMenuOverlayPage: MenuOverlayPage = .settings
    private var currentGameAchievementIDs: [String] = []

    private var isAnimating = false
    private var scenePhase: ScenePhase = .playing
    private var didRecordCurrentGame = false
    private var mergeStreak = 0
    private var pendingSwipe: SwipeDirection?
    private var remainingHints = 3
    private var hapticsEnabled = UserDefaults.standard.object(forKey: "settings.hapticsEnabled") as? Bool ?? true
    private var nightModeEnabled = UserDefaults.standard.bool(forKey: "settings.nightModeEnabled")

    private let scoreFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    private let historyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter
    }()

    private let achievementDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter
    }()

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = DesignSystem.Colors.background
        audioManager.playBackgroundMusic()
        if gridNode == nil {
            setupGrid()
            setupHUD()
            layoutScene()
            prewarmTileTextures()
            startNewGame()
            syncHistoricalAchievements()
        } else {
            layoutScene()
        }
        installInput(on: view)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard gridNode != nil else { return }
        layoutScene()
        rebuildTileNodes()
        updatePreviewTile(animated: false)
    }

    // MARK: - Setup

    private func setupGrid() {
        backgroundNode = SKSpriteNode()
        backgroundNode.zPosition = -100
        addChild(backgroundNode)

        gridNode = SKNode()
        gridNode.zPosition = 10
        addChild(gridNode)
    }

    private func setupHUD() {
        nextCardNode = makeNextHUDCard(size: DesignSystem.Layout.nextCardSize)
        addChild(nextCardNode)

        nextTitleLabel = makeLabel(font: DesignSystem.Fonts.hudLabelFont(), color: DesignSystem.Colors.textDark)
        nextTitleLabel.horizontalAlignmentMode = .center
        nextTitleLabel.fontSize = 14
        nextTitleLabel.text = "NEXT"
        nextTitleLabel.zPosition = 31
        addChild(nextTitleLabel)

        nextPreviewNode = SKNode()
        nextPreviewNode.zPosition = 31
        addChild(nextPreviewNode)

        scoreCardNode = makeHUDCard(size: DesignSystem.Layout.scoreCardSize)
        addChild(scoreCardNode)

        scoreTitleLabel = makeLabel(font: DesignSystem.Fonts.hudLabelFont(), color: DesignSystem.Colors.textDark)
        scoreTitleLabel.horizontalAlignmentMode = .center
        scoreTitleLabel.fontSize = 20
        scoreTitleLabel.text = "SCORE"
        scoreTitleLabel.zPosition = 31
        addChild(scoreTitleLabel)

        scoreValueLabel = makeLabel(font: DesignSystem.Fonts.hudValueFont(), color: DesignSystem.Colors.textDark)
        scoreValueLabel.horizontalAlignmentMode = .center
        scoreValueLabel.fontSize = 54
        scoreValueLabel.text = "0"
        scoreValueLabel.zPosition = 31
        addChild(scoreValueLabel)

        bestValueLabel = makeLabel(font: DesignSystem.Fonts.hudValueFont(), color: DesignSystem.Colors.progressFill)
        bestValueLabel.horizontalAlignmentMode = .center
        bestValueLabel.fontSize = 18
        bestValueLabel.text = ""
        bestValueLabel.alpha = 0
        bestValueLabel.zPosition = 31
        addChild(bestValueLabel)

        menuButton = makeIconButton(
            diameter: 58,
            fillColor: DesignSystem.Colors.buttonBackground,
            icon: "⚙",
            name: NodeName.menuHudButton
        )
        menuButton.zPosition = 30
        addChild(menuButton)

        restartHudButton = makeButton(
            size: CGSize(width: 156, height: 64),
            fillColor: DesignSystem.Colors.buttonBackground,
            text: "↻  RESTART",
            textColor: .white,
            name: NodeName.restartButton
        )
        restartHudButton.zPosition = 30
        addChild(restartHudButton)

        hintHudButton = makeButton(
            size: CGSize(width: 156, height: 64),
            fillColor: DesignSystem.Colors.buttonSecondaryBackground,
            text: "💡  HINT",
            textColor: .white,
            name: NodeName.hintButton
        )
        hintHudButton.zPosition = 30
        addChild(hintHudButton)

        hintBadgeNode = SKShapeNode(circleOfRadius: 15)
        hintBadgeNode.fillColor = DesignSystem.Colors.badgeRed
        hintBadgeNode.strokeColor = UIColor.white.withAlphaComponent(0.62)
        hintBadgeNode.lineWidth = 2
        hintBadgeNode.name = NodeName.hintButton
        hintBadgeNode.zPosition = 33
        hintBadgeLabel = makeLabel(font: DesignSystem.Fonts.hudLabelFont(), color: .white)
        hintBadgeLabel.text = "3"
        hintBadgeLabel.name = NodeName.hintButton
        hintBadgeNode.addChild(hintBadgeLabel)
        addChild(hintBadgeNode)
    }

    private func installInput(on view: SKView) {
        guard inputController == nil else { return }

        let controller = InputController(view: view)
        controller.onSwipe = { [weak self] direction in
            self?.handleSwipe(direction)
        }
        inputController = controller
    }

    // MARK: - Layout

    private func layoutScene() {
        guard let view else { return }

        let safeInsets = view.safeAreaInsets
        let topInset = max(safeInsets.top, 44)
        let bottomInset = max(safeInsets.bottom, 20)

        // 布局比例（用户指定）
        // BEST: y ≈ frame.maxY - 70
        // SCORE: y ≈ frame.maxY - 170
        // 棋盘: y ≈ frame.maxY - 320（棋盘中心）
        // 底部按钮: y ≈ frame.minY + 50
        let bestCenterY = frame.maxY - topInset - 50
        let scoreCenterY = bestCenterY - 98
        let bottomButtonY = frame.minY + bottomInset + 42

        let gridSize = currentGridSize(in: view)
        let topBoardLimit = scoreCenterY - DesignSystem.Layout.scoreCardSize.height / 2 - 22
        let bottomBoardLimit = bottomButtonY + 32 + 22
        let boardCenterY = (topBoardLimit + bottomBoardLimit) / 2

        layoutBackground(size: frame.size)
        gridNode.position = CGPoint(x: frame.midX, y: boardCenterY)

        let rightInset = max(safeInsets.right, 0)
        let horizontalPadding: CGFloat = 28
        let rightCardX = frame.maxX - rightInset - 34

        menuButton.position = CGPoint(x: rightCardX, y: bestCenterY)

        nextCardNode.position = CGPoint(x: frame.midX, y: bestCenterY)
        nextTitleLabel.position = CGPoint(x: frame.midX, y: bestCenterY + 23)
        nextPreviewNode.position = CGPoint(x: frame.midX, y: bestCenterY - 13)
        bestValueLabel.position = CGPoint(x: frame.midX + 42, y: bestCenterY - 2)

        scoreCardNode.position = CGPoint(x: frame.midX, y: scoreCenterY)
        scoreTitleLabel.position = CGPoint(x: frame.midX, y: scoreCenterY + 24)
        scoreValueLabel.position = CGPoint(x: frame.midX, y: scoreCenterY - 14)

        let buttonGap: CGFloat = 18
        let buttonWidth = min(156, (frame.width - horizontalPadding * 2 - buttonGap) / 2)
        restartHudButton.position = CGPoint(x: frame.midX - buttonWidth / 2 - buttonGap / 2, y: bottomButtonY)
        hintHudButton.position = CGPoint(x: frame.midX + buttonWidth / 2 + buttonGap / 2, y: bottomButtonY)
        // Hint 角标更靠右上（悬浮红色气泡感）
        hintBadgeNode.position = CGPoint(x: hintHudButton.position.x + buttonWidth / 2 - 6, y: bottomButtonY + 32)

        layoutGridBackground(gridSize: gridSize)
    }

    private func currentGridSize(in view: SKView) -> CGFloat {
        min(DesignSystem.Layout.gridSize(in: view), view.bounds.height * 0.43)
    }

    private func layoutBackground(size: CGSize) {
        backgroundNode.texture = backgroundTexture(size: size)
        backgroundNode.size = size
        backgroundNode.position = CGPoint(x: frame.midX, y: frame.midY)
    }

    private func layoutGridBackground(gridSize: CGFloat) {
        gridNode.children
            .filter { $0.name == NodeName.cell || $0.name == NodeName.boardPanel }
            .forEach { $0.removeFromParent() }

        let cellSize = DesignSystem.Layout.cellSize(gridSize: gridSize)
        let cellRadius = cellSize / sqrt(3)
        let positions = GameModel.visualPositions.map {
            pointForGridPosition($0, gridSize: gridSize, cellSize: cellSize)
        }
        let minX = positions.map(\.x).min() ?? 0
        let maxX = positions.map(\.x).max() ?? 0
        let minY = positions.map(\.y).min() ?? 0
        let maxY = positions.map(\.y).max() ?? 0
        let boardWidth = maxX - minX + cellSize * 1.36
        let boardHeight = maxY - minY + hexHeight(width: cellSize) * 1.12
        let boardCenter = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)

        let aura = SKShapeNode(ellipseOf: CGSize(width: boardWidth * 1.04, height: boardHeight * 1.06))
        aura.fillColor = DesignSystem.Colors.boardBackground.withAlphaComponent(0.24)
        aura.strokeColor = UIColor.white.withAlphaComponent(0.1)
        aura.lineWidth = 1
        aura.name = NodeName.boardPanel
        aura.position = CGPoint(x: boardCenter.x, y: boardCenter.y - cellSize * 0.04)
        aura.zPosition = -12
        gridNode.addChild(aura)

        let groundShadow = SKShapeNode(ellipseOf: CGSize(width: boardWidth * 0.92, height: boardHeight * 0.92))
        groundShadow.fillColor = UIColor.black.withAlphaComponent(0.16)
        groundShadow.strokeColor = .clear
        groundShadow.name = NodeName.boardPanel
        groundShadow.position = CGPoint(x: boardCenter.x, y: boardCenter.y - cellSize * 0.14)
        groundShadow.zPosition = -11
        gridNode.addChild(groundShadow)

        for position in GameModel.visualPositions {
            let slotPosition = pointForGridPosition(position, gridSize: gridSize, cellSize: cellSize)

            let shadow = SKShapeNode(path: hexPath(radius: cellRadius * 1.08))
            shadow.fillColor = UIColor.black.withAlphaComponent(0.2)
            shadow.strokeColor = .clear
            shadow.name = NodeName.boardPanel
            shadow.position = CGPoint(x: slotPosition.x, y: slotPosition.y - cellSize * 0.07)
            shadow.zPosition = -8
            gridNode.addChild(shadow)

            let base = SKShapeNode(path: hexPath(radius: cellRadius * 1.04))
            base.fillColor = DesignSystem.Colors.boardBackground.withAlphaComponent(0.82)
            base.strokeColor = UIColor.white.withAlphaComponent(0.2)
            base.lineWidth = 1.2
            base.name = NodeName.boardPanel
            base.position = slotPosition
            base.zPosition = -7
            gridNode.addChild(base)

            let inset = SKShapeNode(path: hexPath(radius: cellRadius * 0.9))
            inset.fillColor = DesignSystem.Colors.emptyCell
            inset.strokeColor = DesignSystem.Colors.emptyCellStroke
            inset.lineWidth = 1
            inset.name = NodeName.cell
            inset.position = slotPosition
            inset.zPosition = -5
            gridNode.addChild(inset)

            let highlight = SKShapeNode(path: hexPath(radius: cellRadius * 0.78))
            highlight.fillColor = .clear
            highlight.strokeColor = UIColor.white.withAlphaComponent(0.11)
            highlight.lineWidth = 1
            highlight.name = NodeName.boardPanel
            highlight.position = CGPoint(x: slotPosition.x, y: slotPosition.y + cellSize * 0.04)
            highlight.zPosition = -4
            gridNode.addChild(highlight)
        }

        let rim = SKShapeNode(ellipseOf: CGSize(width: boardWidth * 0.98, height: boardHeight))
        rim.fillColor = .clear
        rim.strokeColor = UIColor.white.withAlphaComponent(0.08)
        rim.lineWidth = 2
        rim.name = NodeName.boardPanel
        rim.position = boardCenter
        rim.zPosition = -3
        gridNode.addChild(rim)
    }

    private func hexPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for index in 0..<6 {
            let angle = CGFloat.pi / 6 + CGFloat(index) * CGFloat.pi / 3
            let point = CGPoint(
                x: radius * cos(angle),
                y: radius * sin(angle)
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    // 保留旧方法但重定向到新方法（兼容其他调用方）
    private func hexPath(width: CGFloat) -> CGPath {
        hexPath(radius: width / sqrt(3))
    }

    private func hexPath(radius: CGFloat, center: CGPoint) -> CGPath {
        let path = CGMutablePath()
        for index in 0..<6 {
            let angle = CGFloat.pi / 6 + CGFloat(index) * CGFloat.pi / 3
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    // 兼容旧调用
    private func hexPath(width: CGFloat, center: CGPoint) -> CGPath {
        hexPath(radius: width / sqrt(3), center: center)
    }

    // MARK: - Game Flow

    private func startNewGame() {
        closeAllOverlays()
        scenePhase = .playing
        didRecordCurrentGame = false
        isAnimating = false
        mergeStreak = 0
        pendingSwipe = nil
        currentGameAchievementIDs.removeAll()
        achievementToastNode?.removeFromParent()
        achievementToastNode = nil
        remainingHints = 3

        model.reset()
        tileNodes.values.forEach { $0.removeFromParent() }
        tileNodes.removeAll()
        previewTileValue = nil
        spawner.reset(for: model.board)

        if let pos1 = model.emptyPositions.randomElement() {
            let firstTile = spawner.takePreviewTile()
            model.place(firstTile, at: pos1)
            spawnTile(at: pos1, value: firstTile.value)
            audioManager.playSpawn()
            spawner.refreshPreview(for: model.board)
        }

        if let pos2 = model.emptyPositions.randomElement() {
            let secondTile = spawner.takePreviewTile()
            model.place(secondTile, at: pos2)
            spawnTile(at: pos2, value: secondTile.value)
            audioManager.playSpawn()
            spawner.refreshPreview(for: model.board)
        }

        updateHUD()
        updateHintBadge()
    }

    private func syncHistoricalAchievements() {
        let snapshot = statsStore.snapshot()
        gameCenterService.syncHistoricalAchievements(
            score: snapshot.bestScore,
            maxTile: snapshot.maxTileEver,
            gamesPlayed: snapshot.gamesPlayed
        )
    }

    private func handleSwipe(_ swipe: SwipeDirection) {
        if scenePhase == .menu {
            switch swipe {
            case .west, .northwest, .southwest:
                showNextMenuOverlayPage()
            case .east, .northeast, .southeast:
                showPreviousMenuOverlayPage()
            }
            return
        }

        guard scenePhase == .playing else { return }
        guard !isAnimating else {
            pendingSwipe = swipe
            return
        }

        let result = model.move(directionForSwipe(swipe))
        guard result.didMove else {
            playImpact(.light)
            mergeStreak = 0
            return
        }

        isAnimating = true
        if result.merges.isEmpty {
            mergeStreak = 0
            audioManager.playMove()
        } else if result.merges.contains(where: { $0.resultValue >= 48 }) {
            mergeStreak += 1
            audioManager.playBigMerge()
        } else {
            mergeStreak += 1
            audioManager.playMerge()
        }
        animateMove(result: result)
    }

    private func directionForSwipe(_ swipe: SwipeDirection) -> MoveDirection {
        switch swipe {
        case .east: return .east
        case .west: return .west
        case .northeast: return .northeast
        case .southwest: return .southwest
        case .northwest: return .northwest
        case .southeast: return .southeast
        }
    }

    private func animateMove(result: MoveResult) {
        for movement in result.movements {
            if let node = tileNodes[movement.from] {
                // 计算六角方向角度，用于旋转动画
                let dx = CGFloat(movement.to.q - movement.from.q)
                let dy = CGFloat(movement.to.r - movement.from.r)
                let moveAngle = atan2(dy, dx + dy * 0.5)

                let destPos = positionForGrid(movement.to)
                let move = SKAction.move(to: destPos, duration: DesignSystem.Animation.moveDuration)
                move.timingMode = .easeOut

                // 滑动时倾斜（沿移动方向），落地前回正
                let tiltForward = SKAction.rotate(toAngle: moveAngle * 0.12, duration: DesignSystem.Animation.moveDuration * 0.6, shortestUnitArc: true)
                tiltForward.timingMode = .easeIn
                let tiltBack = SKAction.rotate(toAngle: 0, duration: DesignSystem.Animation.moveDuration * 0.4, shortestUnitArc: true)
                tiltBack.timingMode = .easeOut

                node.run(SKAction.group([move, SKAction.sequence([tiltForward, tiltBack])]))
            }
        }

        run(SKAction.wait(forDuration: DesignSystem.Animation.moveDuration)) { [weak self] in
            self?.finishMove(result: result)
        }
    }

    private func finishMove(result: MoveResult) {
        applyMoveResultToTileNodes(result)

        if let spawnPos = result.spawnCandidates.randomElement() {
            let spawnedTile = spawner.takePreviewTile()
            model.place(spawnedTile, at: spawnPos)
            spawnTile(at: spawnPos, value: spawnedTile.value)
            audioManager.playSpawn()
        }
        spawner.refreshPreview(for: model.board)

        updateHUD()
        showMergeFeedback(for: result)
        unlockRealtimeAchievementsIfNeeded()
        isAnimating = false

        if model.isGameOver {
            showGameOver()
        } else if let pendingSwipe {
            self.pendingSwipe = nil
            run(.wait(forDuration: 0.015)) { [weak self] in
                self?.handleSwipe(pendingSwipe)
            }
        }
    }

    private func applyMoveResultToTileNodes(_ result: MoveResult) {
        var updatedNodes = tileNodes

        for movement in result.movements where movement.consumedInMerge {
            if let node = updatedNodes.removeValue(forKey: movement.from) {
                node.removeFromParent()
            }
        }

        for movement in result.movements where !movement.consumedInMerge {
            guard let node = updatedNodes.removeValue(forKey: movement.from) else { continue }
            node.position = positionForGrid(movement.to)
            node.zRotation = 0 // 重置倾斜角度
            updatedNodes[movement.to] = node
        }

        for merge in result.merges {
            let node = makeTileNode(value: merge.resultValue)
            node.position = positionForGrid(merge.at)
            node.setScale(0.9)
            gridNode.addChild(node)
            updatedNodes[merge.at] = node

            let pop = SKAction.scale(to: 1, duration: DesignSystem.Animation.mergeDuration)
            pop.timingMode = .easeOut
            node.run(pop)
        }

        tileNodes = updatedNodes
    }

    // MARK: - Tile Nodes

    private func positionForGrid(_ pos: GridPosition) -> CGPoint {
        guard let view else { return .zero }
        let gridSize = currentGridSize(in: view)
        let cellSize = DesignSystem.Layout.cellSize(gridSize: gridSize)
        return pointForGridPosition(
            pos,
            gridSize: gridSize,
            cellSize: cellSize
        )
    }

    private func pointForGridPosition(
        _ pos: GridPosition,
        gridSize: CGFloat,
        cellSize: CGFloat
    ) -> CGPoint {
        let verticalStep = hexHeight(width: cellSize) * 0.75
        let x = cellSize * (CGFloat(pos.q) + CGFloat(pos.r) / 2)
        let y = -verticalStep * CGFloat(pos.r)
        return CGPoint(x: x, y: y)
    }

    private func spawnTile(at pos: GridPosition, value: Int) {
        let node = makeTileNode(value: value)
        node.position = positionForGrid(pos)
        node.setScale(0)
        gridNode.addChild(node)
        tileNodes[pos] = node

        let scaleUp = SKAction.scale(to: 1, duration: DesignSystem.Animation.spawnDuration)
        scaleUp.timingMode = .easeOut
        node.run(scaleUp)
    }

    private func makeTileNode(value: Int) -> SKSpriteNode {
        guard let view else { return SKSpriteNode() }
        let gridSize = currentGridSize(in: view)
        let cellSize = DesignSystem.Layout.cellSize(gridSize: gridSize)
        return makeTileNode(value: value, size: cellSize)
    }

    private func makeTileNode(value: Int, size: CGFloat) -> SKSpriteNode {
        let texture = tileTexture(value: value, size: size)
        let node = SKSpriteNode(texture: texture, size: CGSize(width: size, height: hexHeight(width: size)))
        node.zPosition = 2
        return node
    }

    private func prewarmTileTextures() {
        guard let view else { return }

        let gridSize = currentGridSize(in: view)
        let cellSize = DesignSystem.Layout.cellSize(gridSize: gridSize)
        let commonValues = [1, 2, 3, 6, 12, 24, 48, 96, 192, 384, 768]
        for value in commonValues {
            _ = tileTexture(value: value, size: cellSize)
            _ = tileTexture(value: value, size: DesignSystem.Layout.previewTileSize.width)
        }
    }

    private func hexHeight(width: CGFloat) -> CGFloat {
        width * 2 / sqrt(3)
    }

    private func tileTexture(value: Int, size: CGFloat) -> SKTexture {
        let key = TileTextureKey(value: value, size: Int(size.rounded()))
        if let cached = tileTextureCache[key] {
            return cached
        }

        let height = hexHeight(width: size)
        let hexRadius = size / sqrt(3)
        let center = CGPoint(x: size / 2, y: height / 2)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: height))
        let image = renderer.image { context in
            let cgContext = context.cgContext
            let path = UIBezierPath(cgPath: hexPath(radius: hexRadius - 1, center: center))
            let baseColor = DesignSystem.Colors.tileBackground(for: value)
            let highlightColor = DesignSystem.Colors.tileHighlight(for: value)
            let darkColor = DesignSystem.Colors.tileBottomDark(for: value)

            // === 1. 外投影（棋子浮起感）===
            let outerPath = UIBezierPath(cgPath: hexPath(radius: hexRadius + 2, center: CGPoint(x: center.x, y: center.y - 1)))
            cgContext.saveGState()
            cgContext.setShadow(offset: CGSize(width: 0, height: -2), blur: 5, color: UIColor.black.withAlphaComponent(0.35).cgColor)
            darkColor.withAlphaComponent(0.5).setFill()
            outerPath.fill()
            cgContext.restoreGState()

            // === 2. 底部暗边（糖果厚度感）===
            let bottomPath = UIBezierPath(cgPath: hexPath(radius: hexRadius - 1, center: CGPoint(x: center.x, y: center.y + 2)))
            darkColor.setFill()
            bottomPath.fill()

            // === 3. 主渐变填充 ===
            cgContext.saveGState()
            path.addClip()
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [highlightColor.cgColor, baseColor.cgColor, darkColor.cgColor] as CFArray,
                locations: [0, 0.45, 1]
            ) {
                cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: size * 0.15, y: height * 0.08),
                    end: CGPoint(x: size * 0.88, y: height * 0.92),
                    options: []
                )
            } else {
                baseColor.setFill()
                path.fill()
            }
            cgContext.restoreGState()

            // === 4. 顶部高光条（玻璃质感）===
            let barHeight = max(3.5, height * 0.065)
            let barWidth = size * 0.42
            let barPath = UIBezierPath(
                roundedRect: CGRect(
                    x: center.x - barWidth / 2,
                    y: height * 0.13,
                    width: barWidth,
                    height: barHeight
                ),
                cornerRadius: barHeight / 2
            )
            UIColor.white.withAlphaComponent(0.48).setFill()
            barPath.fill()

            // === 5. 内阴影（凹陷感）===
            let innerPath = UIBezierPath(cgPath: hexPath(radius: hexRadius - 3, center: center))
            UIColor.black.withAlphaComponent(0.12).setStroke()
            innerPath.lineWidth = 1.5
            innerPath.stroke()

            // === 6. 外描边 ===
            UIColor.white.withAlphaComponent(0.3).setStroke()
            path.lineWidth = 1
            path.stroke()

            // === 7. 数字文字（白色粗体 + 描边 + 阴影）===
            let tileFont = DesignSystem.Fonts.tileFont(for: value)
            let rawFontSize = min(tileFont.pointSize, size * 0.58)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let text = "\(value)" as NSString
            let measuringAttributes: [NSAttributedString.Key: Any] = [.font: tileFont.withSize(rawFontSize)]
            let measuredWidth = text.size(withAttributes: measuringAttributes).width
            let maxTextWidth = size * 0.72
            let fittedFontSize = measuredWidth > maxTextWidth
                ? max(12, rawFontSize * maxTextWidth / measuredWidth)
                : rawFontSize
            let font = tileFont.withSize(fittedFontSize)

            // 文字阴影
            let shadow = NSShadow()
            shadow.shadowBlurRadius = 4
            shadow.shadowOffset = CGSize(width: 0, height: 2)
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.45)

            // 文字描边
            let strokeColor = UIColor.black.withAlphaComponent(0.25)

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: DesignSystem.Colors.tileText(for: value),
                .paragraphStyle: paragraph,
                .shadow: shadow
            ]
            let strokeAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: strokeColor,
                .paragraphStyle: paragraph
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: 0,
                y: (height - textSize.height) / 2 - height * 0.03,
                width: size,
                height: textSize.height
            )
            // 先画描边
            text.draw(in: textRect, withAttributes: strokeAttributes)
            // 再画主体
            text.draw(in: textRect, withAttributes: attributes)
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        tileTextureCache[key] = texture
        return texture
    }

    private func makeGradientTexture(width: Int, height: Int, topColor: UIColor, bottomColor: UIColor) -> SKTexture {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cgContext = ctx.cgContext
            let colors = [topColor.cgColor, bottomColor.cgColor] as CFArray
            let locations: [CGFloat] = [0, 1]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
                cgContext.drawLinearGradient(gradient, start: CGPoint(x: CGFloat(width) / 2, y: CGFloat(height)), end: CGPoint(x: CGFloat(width) / 2, y: 0), options: [])
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }

    private func backgroundTexture(size: CGSize) -> SKTexture {
        let key = BackgroundTextureKey(width: Int(size.width.rounded()), height: Int(size.height.rounded()))
        if let cached = backgroundTextureCache[key] {
            return cached
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cgContext = context.cgContext

            // === 1. 背景渐变 ===
            let colors = nightModeEnabled
                ? [
                    UIColor(hex: "#123C86").cgColor,
                    UIColor(hex: "#071A4A").cgColor,
                    UIColor(hex: "#050816").cgColor
                ] as CFArray
                : [
                    DesignSystem.Colors.backgroundGlow.cgColor,
                    DesignSystem.Colors.background.cgColor,
                    DesignSystem.Colors.backgroundDeep.cgColor
                ] as CFArray
            let locations: [CGFloat] = [0, 0.56, 1]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
                cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }

            // === 2. Radial glow（聚焦棋盘区域）===
            let centerX = size.width / 2
            let centerY = size.height * 0.5
            let glowRadius = size.width * 0.6
            let radialColors = [
                UIColor.white.withAlphaComponent(0.08).cgColor,
                UIColor.clear.cgColor
            ] as CFArray
            let radialLocations: [CGFloat] = [0, 1]
            if let radialGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: radialColors,
                locations: radialLocations
            ) {
                cgContext.drawRadialGradient(
                    radialGradient,
                    startCenter: CGPoint(x: centerX, y: centerY),
                    startRadius: 0,
                    endCenter: CGPoint(x: centerX, y: centerY),
                    endRadius: glowRadius,
                    options: []
                )
            }

            // === 3. 顶部柔边光 ===
            UIColor.white.withAlphaComponent(0.12).setFill()
            cgContext.fillEllipse(in: CGRect(
                x: -size.width * 0.22,
                y: -size.height * 0.12,
                width: size.width * 0.72,
                height: size.width * 0.72
            ))

            // === 4. 右下金色光斑 ===
            DesignSystem.Colors.progressFill.withAlphaComponent(0.06).setFill()
            cgContext.fillEllipse(in: CGRect(
                x: size.width * 0.62,
                y: size.height * 0.08,
                width: size.width * 0.52,
                height: size.width * 0.52
            ))

            // === 5. 斜线纹理（透明度大幅降低，不再抢棋盘注意力）===
            UIColor.white.withAlphaComponent(0.07).setStroke()
            cgContext.setLineWidth(1)
            let step: CGFloat = 34
            var x: CGFloat = -size.height
            while x < size.width {
                cgContext.move(to: CGPoint(x: x, y: 0))
                cgContext.addLine(to: CGPoint(x: x + size.height, y: size.height))
                x += step
            }
            cgContext.strokePath()
        }

        let texture = SKTexture(image: image)
        backgroundTextureCache[key] = texture
        return texture
    }

    private func rebuildTileNodes() {
        tileNodes.values.forEach { $0.removeFromParent() }
        tileNodes.removeAll()

        for pos in GameModel.visualPositions {
            if let tile = model.tile(at: pos) {
                let node = makeTileNode(value: tile.value)
                node.position = positionForGrid(pos)
                gridNode.addChild(node)
                tileNodes[pos] = node
            }
        }
    }

    // MARK: - HUD

    private func updateHUD() {
        scoreValueLabel.text = formatScore(model.score)
        bestValueLabel.text = ""
        updatePreviewTile(animated: true)
        updateHintBadge()
    }

    private func updateHintBadge() {
        hintBadgeLabel.text = "\(remainingHints)"
        hintBadgeNode.isHidden = remainingHints <= 0
        hintHudButton.alpha = remainingHints <= 0 ? 0.62 : 1
    }

    private func showMergeFeedback(for result: MoveResult) {
        guard !result.merges.isEmpty else { return }

        // 给即将合并的棋子添加 glow 特效
        addMergeGlowEffect(merges: result.merges)

        let gained = result.merges.reduce(0) { $0 + $1.resultValue }

        // 升级浮动分数：白色描边 + 更醒目的样式
        let label = makeLabel(font: DesignSystem.Fonts.hudValueFont(), color: DesignSystem.Colors.progressFill)
        label.zPosition = 60
        label.text = mergeStreak >= 2 ? "+\(gained)  x\(mergeStreak)" : "+\(gained)"
        // 加粗放大
        label.fontSize = 26

        if let largestMerge = result.merges.max(by: { $0.resultValue < $1.resultValue }) {
            label.position = gridNode.convert(positionForGrid(largestMerge.at), to: self)
            if largestMerge.resultValue >= 48 {
                playMilestoneEffect(at: label.position, value: largestMerge.resultValue)
            }
        } else {
            label.position = CGPoint(x: frame.midX, y: frame.midY)
        }

        addChild(label)

        // 分数先快速放大再上升消失
        label.setScale(0.4)
        let scaleIn = SKAction.scale(to: 1.1, duration: 0.12)
        scaleIn.timingMode = .easeOut
        let scaleRest = SKAction.scale(to: 1, duration: 0.06)
        let lift = SKAction.moveBy(x: 0, y: 34, duration: 0.38)
        lift.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: 0.34)
        label.run(.sequence([
            scaleIn,
            scaleRest,
            .group([lift, fade]),
            .removeFromParent()
        ]))

        if mergeStreak >= 3 {
            playImpact(.heavy)
        } else {
            playImpact(.medium)
        }
    }

    private func addMergeGlowEffect(merges: [MergeEvent]) {
        for merge in merges {
            // 找到参与合并的两个位置附近的目标格
            // glow 是一个半透明的发光圆
            let glowRadius = DesignSystem.Layout.cellSize(gridSize: currentGridSize(in: view!)) * 0.8
            let glowNode = SKShapeNode(circleOfRadius: glowRadius)
            glowNode.fillColor = DesignSystem.Colors.tileGlow(for: merge.resultValue)
            glowNode.strokeColor = .clear
            glowNode.alpha = 0
            glowNode.zPosition = 3
            glowNode.position = positionForGrid(merge.at)
            gridNode.addChild(glowNode)

            // 脉冲动画
            let pulse = SKAction.sequence([
                SKAction.fadeIn(withDuration: 0.06),
                SKAction.fadeOut(withDuration: 0.14),
                .removeFromParent()
            ])
            glowNode.run(pulse)
        }
    }

    private func playMilestoneEffect(at position: CGPoint, value: Int) {
        let scaleUp = SKAction.scale(to: 1.025, duration: 0.055)
        let scaleBack = SKAction.scale(to: 1, duration: 0.075)
        gridNode.run(.sequence([scaleUp, scaleBack]), withKey: "milestonePulse")

        let color = DesignSystem.Colors.tileBackground(for: value)
        for index in 0..<8 {
            let spark = SKShapeNode(circleOfRadius: 3.2)
            spark.fillColor = color
            spark.strokeColor = .clear
            spark.zPosition = 58
            spark.position = position
            addChild(spark)

            let angle = CGFloat(index) / 8 * .pi * 2
            let distance: CGFloat = 42
            let move = SKAction.moveBy(
                x: cos(angle) * distance,
                y: sin(angle) * distance,
                duration: 0.28
            )
            move.timingMode = .easeOut
            spark.run(.sequence([.group([move, .fadeOut(withDuration: 0.28)]), .removeFromParent()]))
        }
    }

    private func updatePreviewTile(animated: Bool) {
        guard nextPreviewNode != nil else { return }
        nextPreviewNode.removeAllChildren()

        let tileValue = spawner.previewTile.value

        // 显示真正的下一个棋子预览
        let previewSize: CGFloat = DesignSystem.Layout.previewTileSize.width
        let tileNode = makeTileNode(value: tileValue, size: previewSize)
        tileNode.position = .zero
        tileNode.setScale(animated ? 0 : 1)
        nextPreviewNode.addChild(tileNode)

        previewTileValue = tileValue

        if animated {
            let pop = SKAction.scale(to: 1, duration: DesignSystem.Animation.previewDuration)
            pop.timingMode = .easeOut
            tileNode.run(pop)
        }
    }

    private func showGameOver() {
        let wasGameOver = scenePhase == .gameOver
        let achievementUnlocks = recordCurrentGameIfNeeded()
        if !wasGameOver {
            audioManager.playGameOver()
        }
        scenePhase = .gameOver
        updateGameOverAppearance(isActive: true)
        pushOverlay(phase: .gameOver, animated: true)
        showAchievementToasts(achievementUnlocks)
    }

    private func formatScore(_ score: Int) -> String {
        scoreFormatter.string(from: NSNumber(value: score)) ?? "\(score)"
    }

    private func recordCurrentGameIfNeeded() -> [AchievementUnlock] {
        guard !didRecordCurrentGame else { return [] }

        let previousBest = statsStore.bestScore()
        let completedGamesPlayed = statsStore.snapshot().gamesPlayed + 1
        let gameOverUnlocks = gameCenterService.reportAchievements(
            score: model.score,
            maxTile: model.maxTileValue,
            gamesPlayed: completedGamesPlayed
        )
        rememberCurrentGameAchievements(gameOverUnlocks)

        statsStore.recordGame(
            resultScore: model.score,
            histogram: model.tileHistogramFromThree(),
            boardSnapshot: model.boardSnapshot,
            unlockedAchievementIDs: currentGameAchievementIDs
        )

        if model.score >= previousBest {
            gameCenterService.submit(score: model.score)
        }

        didRecordCurrentGame = true
        return gameOverUnlocks
    }

    private func unlockRealtimeAchievementsIfNeeded() {
        let unlocks = gameCenterService.reportAchievements(
            score: model.score,
            maxTile: model.maxTileValue,
            gamesPlayed: statsStore.snapshot().gamesPlayed
        )
        rememberCurrentGameAchievements(unlocks)
        showAchievementToasts(unlocks)
    }

    private func rememberCurrentGameAchievements(_ unlocks: [AchievementUnlock]) {
        for unlock in unlocks where !currentGameAchievementIDs.contains(unlock.identifier) {
            currentGameAchievementIDs.append(unlock.identifier)
        }
    }

    /// 游戏化统计卡片（History 页用）
    private func makeGameStatsCard(snapshot: StatsSnapshot) -> SKNode {
        let root = SKNode()

        let items = [
            ("最高分", formatScore(snapshot.bestScore)),
            ("最高块", "\(snapshot.maxTileEver)"),
            ("局数", "\(snapshot.gamesPlayed)")
        ]

        let cardColors: [UIColor] = [
            DesignSystem.Colors.goldWarm.withAlphaComponent(0.25),
            DesignSystem.Colors.goldWarm.withAlphaComponent(0.18),
            DesignSystem.Colors.goldWarm.withAlphaComponent(0.12)
        ]

        for (index, item) in items.enumerated() {
            let card = SKShapeNode(rectOf: CGSize(width: 98, height: 58), cornerRadius: 14)
            card.fillColor = cardColors[index]
            card.strokeColor = DesignSystem.Colors.glassCardStroke
            card.lineWidth = 1
            card.position = CGPoint(x: -102 + CGFloat(index) * 102, y: 0)
            root.addChild(card)

            // 顶部金色装饰线
            let topLine = SKShapeNode(rectOf: CGSize(width: 30, height: 2), cornerRadius: 1)
            topLine.fillColor = DesignSystem.Colors.goldAccent.withAlphaComponent(0.7)
            topLine.strokeColor = .clear
            topLine.position = CGPoint(x: 0, y: 22)
            card.addChild(topLine)

            let label = makeLabel(font: DesignSystem.Fonts.badgeFont(), color: DesignSystem.Colors.textMuted)
            label.text = item.0
            label.position = CGPoint(x: 0, y: 8)
            card.addChild(label)

            let value = makeLabel(font: DesignSystem.Fonts.scoreDisplayFont(), color: .white)
            value.text = item.1
            value.position = CGPoint(x: 0, y: -12)
            card.addChild(value)
        }

        return root
    }

    /// 游戏化历史记录行（带排名徽章）
    private func makeGameHistoryRow(game: GameRecord, rank: Int) -> SKNode {
        let row = SKNode()

        let background = SKShapeNode(rectOf: CGSize(width: 296, height: 58), cornerRadius: 16)
        background.fillColor = DesignSystem.Colors.glassCardBg
        background.strokeColor = rank == 1
            ? DesignSystem.Colors.goldWarm.withAlphaComponent(0.4)
            : DesignSystem.Colors.separator
        background.lineWidth = 1
        row.addChild(background)

        // 排名徽章
        let rankColors = [DesignSystem.Colors.rankGold, DesignSystem.Colors.rankSilver, DesignSystem.Colors.rankBronze]
        let rankColor = rank <= 3 ? rankColors[rank - 1] : DesignSystem.Colors.textMuted

        let badge = SKShapeNode(circleOfRadius: 16)
        badge.fillColor = rank <= 3 ? rankColor.withAlphaComponent(0.25) : UIColor.clear
        badge.strokeColor = rank <= 3 ? rankColor.withAlphaComponent(0.5) : DesignSystem.Colors.separator
        badge.lineWidth = 1.5
        badge.position = CGPoint(x: -118, y: 0)
        row.addChild(badge)

        let rankLabel = makeLabel(
            font: DesignSystem.Fonts.rankNumberFont(),
            color: rank <= 3 ? rankColor : DesignSystem.Colors.textMuted
        )
        rankLabel.text = "\(rank)"
        rankLabel.position = CGPoint(x: -118, y: 0)
        row.addChild(rankLabel)

        // 棋盘快照缩略图
        let board = makeHistoryBoardSnapshot(game.boardSnapshot, tileSize: 8, spacing: 1.5, showValues: false)
        board.position = CGPoint(x: -72, y: 0)
        row.addChild(board)

        // 分数
        let scoreLabel = makeLabel(font: DesignSystem.Fonts.cardTitleFont(), color: .white)
        scoreLabel.text = formatScore(game.score)
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: -24, y: 6)
        row.addChild(scoreLabel)

        // 日期
        let dateLabel = makeLabel(font: DesignSystem.Fonts.badgeFont(), color: DesignSystem.Colors.textMuted)
        dateLabel.text = historyDateFormatter.string(from: game.playedAt)
        dateLabel.horizontalAlignmentMode = .left
        dateLabel.position = CGPoint(x: -24, y: -12)
        row.addChild(dateLabel)

        return row
    }

    private func makeHistoryBoardSnapshot(
        _ snapshot: [Int]?,
        tileSize: CGFloat,
        spacing: CGFloat,
        showValues: Bool
    ) -> SKNode {
        let root = SKNode()
        let values = normalizedSnapshot(snapshot)
        let boardWidth = tileSize * 5
        let boardHeight = hexHeight(width: tileSize) + hexHeight(width: tileSize) * 0.75 * 4

        let background = SKShapeNode(rectOf: CGSize(width: boardWidth + 10, height: boardHeight + 8), cornerRadius: max(6, tileSize * 0.5))
        background.fillColor = DesignSystem.Colors.boardBackground.withAlphaComponent(0.42)
        background.strokeColor = UIColor.white.withAlphaComponent(0.5)
        background.lineWidth = 1
        root.addChild(background)

        for (index, position) in GameModel.visualPositions.enumerated() {
            let value = index < values.count ? values[index] : 0
            let cell = SKShapeNode(path: hexPath(width: tileSize))
            cell.fillColor = value > 0 ? DesignSystem.Colors.tileBackground(for: value) : DesignSystem.Colors.emptyCell
            cell.strokeColor = UIColor.white.withAlphaComponent(value > 0 ? 0.28 : 0.14)
            cell.lineWidth = 0.7
            cell.alpha = 1
            cell.position = pointForGridPosition(position, gridSize: boardWidth, cellSize: tileSize)
            root.addChild(cell)

            if showValues, value > 0 {
                let label = makeLabel(font: DesignSystem.Fonts.tileFont(for: value), color: DesignSystem.Colors.tileText(for: value))
                label.fontSize = value < 100 ? 18 : 15
                label.text = "\(value)"
                label.position = cell.position
                root.addChild(label)
            }
        }

        return root
    }

    private func normalizedSnapshot(_ snapshot: [Int]?) -> [Int] {
        var values = snapshot ?? []
        if values.count < GameModel.boardCellCount {
            values += Array(repeating: 0, count: GameModel.boardCellCount - values.count)
        }
        return Array(values.prefix(GameModel.boardCellCount))
    }

    // MARK: - Overlay Navigation

    /// Vertical push for menu pages, horizontal for inner content pages
    private func pushOverlay(phase: ScenePhase, animated: Bool = true) {
        // Build page if not cached
        let page: SKNode
        if let existing = overlayPages[phase] {
            page = existing
        } else {
            page = buildOverlayPage(for: phase)
            overlayPages[phase] = page
        }

        // Ensure root exists
        if overlayRoot == nil {
            overlayRoot = SKNode()
            overlayRoot?.zPosition = 100
            addChild(overlayRoot!)
        }

        guard let root = overlayRoot else { return }

        // Determine animation direction
        let isGameOver = phase == .gameOver
        let isVertical = phase == .menu
        let verticalOffset: CGFloat = frame.height
        let horizontalOffset: CGFloat = frame.width
        let startX: CGFloat = isVertical ? 0 : (phase == .history ? -horizontalOffset : horizontalOffset)
        let endX: CGFloat = 0

        page.position = isGameOver ? .zero : CGPoint(x: startX, y: isVertical ? -verticalOffset : 0)
        page.zPosition = root.zPosition + 10
        root.addChild(page)

        let duration: TimeInterval = animated ? 0.28 : 0.01
        let slide: SKAction
        if isGameOver {
            page.alpha = animated ? 0 : 1
            slide = SKAction.fadeIn(withDuration: duration)
        } else if isVertical {
            slide = SKAction.move(to: CGPoint(x: 0, y: 0), duration: duration)
        } else {
            slide = SKAction.move(to: CGPoint(x: endX, y: 0), duration: duration)
        }
        slide.timingMode = .easeOut

        if animated {
            isAnimating = true
            page.run(SKAction.sequence([
                slide,
                SKAction.run { [weak self] in self?.isAnimating = false }
            ]))
        } else {
            page.position = CGPoint(x: endX, y: 0)
            page.alpha = 1
        }

        pageStack.append(phase)
        scenePhase = phase
    }

    private func popOverlay(animated: Bool = true) {
        guard pageStack.count >= 2 else {
            closeAllOverlays()
            return
        }

        let currentPhase = pageStack.removeLast()
        let previousPhase = pageStack[pageStack.count - 1]

        guard overlayRoot != nil,
              let currentPage = overlayPages[currentPhase] else { return }

        let isVertical = currentPhase == .menu
        let verticalOffset: CGFloat = frame.height
        let horizontalOffset: CGFloat = frame.width
        let endX: CGFloat = isVertical ? -horizontalOffset : (currentPhase == .history ? horizontalOffset : -horizontalOffset)

        let duration: TimeInterval = animated ? 0.24 : 0.01
        let slide: SKAction
        if isVertical {
            slide = SKAction.move(to: CGPoint(x: 0, y: -verticalOffset), duration: duration)
        } else {
            slide = SKAction.move(to: CGPoint(x: endX, y: 0), duration: duration)
        }
        slide.timingMode = .easeIn

        if animated {
            isAnimating = true
            let fade = SKAction.run {
                currentPage.removeFromParent()
                self.isAnimating = false
                self.scenePhase = previousPhase
            }
            currentPage.run(SKAction.sequence([slide, fade]))
        } else {
            currentPage.removeFromParent()
            scenePhase = previousPhase
        }
    }

    private func closeAllOverlays() {
        infoDialogNode?.removeFromParent()
        infoDialogNode = nil
        overlayRoot?.removeFromParent()
        overlayRoot = nil
        overlayPages.removeAll()
        pageStack.removeAll()
        currentMenuOverlayPage = .settings
        scenePhase = .playing
        isAnimating = false
        updateGameOverAppearance(isActive: false)
    }

    private func rebuildOverlayPage(for phase: ScenePhase) {
        let oldPage = overlayPages[phase]
        let rebuiltPage = buildOverlayPage(for: phase)
        overlayPages[phase] = rebuiltPage

        guard pageStack.last == phase else { return }
        guard let root = overlayRoot else { return }

        rebuiltPage.position = oldPage?.position ?? .zero
        rebuiltPage.zPosition = oldPage?.zPosition ?? root.zPosition + 10
        root.addChild(rebuiltPage)
        oldPage?.removeFromParent()
    }

    private func updateGameOverAppearance(isActive: Bool) {
        let boardAlpha: CGFloat = isActive ? 0.42 : 1
        let hudAlpha: CGFloat = isActive ? 0.72 : 1

        backgroundNode.alpha = isActive ? 0.58 : 1
        gridNode.alpha = boardAlpha
        nextCardNode.alpha = hudAlpha
        nextTitleLabel.alpha = hudAlpha
        nextPreviewNode.alpha = hudAlpha
        scoreCardNode.alpha = hudAlpha
        scoreTitleLabel.alpha = hudAlpha
        scoreValueLabel.alpha = hudAlpha
        bestValueLabel.alpha = 0
        menuButton.alpha = isActive ? 0.4 : 1
        restartHudButton.alpha = isActive ? 0.42 : 1
        hintHudButton.alpha = isActive ? 0.42 : 1
        hintBadgeNode.alpha = isActive ? 0.28 : 1
    }

    private func makeOverlayBackground(size: CGSize) -> SKNode {
        let root = SKNode()

        // 深色渐变底
        let gradient = SKSpriteNode(color: .clear, size: size)
        gradient.position = CGPoint(x: size.width / 2, y: size.height / 2)
        gradient.zPosition = -2
        let gradientTex = makeGradientTexture(width: Int(size.width), height: Int(size.height),
            topColor: DesignSystem.Colors.overlayGradientTop,
            bottomColor: DesignSystem.Colors.overlayGradientBottom)
        gradient.texture = gradientTex
        root.addChild(gradient)

        // 金色中心光晕（聚焦在屏幕中央偏上）
        let cx = size.width / 2
        let cy = size.height * 0.48
        let glowRadius = min(size.width, size.height) * 0.45
        let glowNode = SKShapeNode(circleOfRadius: glowRadius)
        let glowColor = DesignSystem.Colors.goldWarm.withAlphaComponent(0.06)
        glowNode.fillColor = glowColor
        glowNode.strokeColor = .clear
        glowNode.position = CGPoint(x: cx, y: cy)
        glowNode.zPosition = -1
        root.addChild(glowNode)

        // 星尘粒子
        let sparkCount = 48
        for _ in 0..<sparkCount {
            let spark = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.8...2.4))
            let brightness = CGFloat.random(in: 0.2...0.7)
            spark.fillColor = UIColor.white.withAlphaComponent(brightness)
            spark.strokeColor = .clear
            spark.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            spark.zPosition = 0
            spark.alpha = CGFloat.random(in: 0.1...0.5)
            root.addChild(spark)
        }

        return root
    }

    // MARK: - Overlay Page Builders

    private func buildOverlayPage(for phase: ScenePhase) -> SKNode {
        let page = SKNode()

        if phase != .gameOver {
            let bg = makeOverlayBackground(size: frame.size)
            page.addChild(bg)
        }

        switch phase {
        case .gameOver:
            buildGameOverPage(into: page)
        case .history:
            buildHistoryPage(into: page)
        case .menu:
            buildMenuPage(into: page)
        case .settings:
            buildSettingsPage(into: page)
        case .about:
            buildPrivacyPage(into: page)
        case .privacy:
            buildPrivacyPage(into: page)
        default:
            break
        }
        return page
    }

    // MARK: - Touches

    // MARK: - Page Content Builders

    private func buildGameOverPage(into page: SKNode) {
        guard let view else { return }

        let gridSize = DesignSystem.Layout.gridSize(in: view)
        let boardBottomY = gridNode.position.y - gridSize / 2 - 9
        let buttonY = boardBottomY - 66

        let title = makeLabel(font: DesignSystem.Fonts.modalTitleFont(), color: DesignSystem.Colors.textDark)
        title.text = "游戏结束"
        title.position = CGPoint(x: frame.midX, y: buttonY + 56)
        page.addChild(title)

        let restartButton = makeButton(
            size: CGSize(width: 180, height: DesignSystem.Layout.modalButtonHeight),
            fillColor: DesignSystem.Colors.buttonBackground,
            text: "重来一局",
            textColor: .white,
            name: NodeName.restartButton
        )
        restartButton.position = CGPoint(x: frame.midX, y: buttonY)
        page.addChild(restartButton)
    }

    private func buildHistoryPage(into page: SKNode) {
        let cx = frame.midX
        let topInset = max(view?.safeAreaInsets.top ?? 44, 44)
        let bottomInset = max(view?.safeAreaInsets.bottom ?? 24, 24)
        let snapshot = statsStore.snapshot()

        // 标题
        let titleY = frame.maxY - topInset - 56
        let titleBar = SKShapeNode(rectOf: CGSize(width: 148, height: 36), cornerRadius: 18)
        titleBar.fillColor = DesignSystem.Colors.goldWarm.withAlphaComponent(0.12)
        titleBar.strokeColor = DesignSystem.Colors.goldWarm.withAlphaComponent(0.28)
        titleBar.lineWidth = 1.5
        titleBar.position = CGPoint(x: cx, y: titleY)
        page.addChild(titleBar)

        let title = makeLabel(font: DesignSystem.Fonts.overlayTitleFont(), color: DesignSystem.Colors.menuTitleGold)
        title.text = "历史记录"
        title.position = CGPoint(x: cx, y: titleY)
        title.zPosition = 2
        page.addChild(title)

        // 统计卡片
        let summaryY = titleY - 78
        let summary = makeGameStatsCard(snapshot: snapshot)
        summary.position = CGPoint(x: cx, y: summaryY)
        page.addChild(summary)

        // 最近对局标题
        let listTitleY = summaryY - 72
        let listTitle = makeLabel(font: DesignSystem.Fonts.cardTitleFont(), color: DesignSystem.Colors.menuTitleGold)
        listTitle.horizontalAlignmentMode = .left
        listTitle.text = "最近对局"
        listTitle.position = CGPoint(x: cx - 140, y: listTitleY + 30)
        page.addChild(listTitle)

        // 游戏记录列表
        let listStartY = listTitleY - 12
        if snapshot.recentGames.isEmpty {
            let emptyLabel = makeLabel(font: DesignSystem.Fonts.cardSubtitleFont(), color: DesignSystem.Colors.textMuted)
            emptyLabel.text = "还没有历史记录，先玩几局再回来看看"
            emptyLabel.position = CGPoint(x: cx, y: listStartY - 24)
            page.addChild(emptyLabel)
        } else {
            for (index, game) in snapshot.recentGames.prefix(min(5, snapshot.recentGames.count)).enumerated() {
                let row = makeGameHistoryRow(game: game, rank: index + 1)
                row.position = CGPoint(x: cx, y: listStartY - CGFloat(index) * 68)
                page.addChild(row)
            }
        }

        // 底部关闭按钮
        let closeBtnY = frame.minY + bottomInset + 58
        let closeButton = makeGoldButton(
            size: CGSize(width: 180, height: 48),
            text: "关闭",
            name: NodeName.closeMenuButton
        )
        closeButton.position = CGPoint(x: cx, y: closeBtnY)
        page.addChild(closeButton)
    }

    private func buildMenuPage(into page: SKNode) {
        let cx = frame.midX
        let topInset = max(view?.safeAreaInsets.top ?? 44, 44)
        let bottomInset = max(view?.safeAreaInsets.bottom ?? 24, 24)
        let titleY = frame.maxY - topInset - 62
        let buttonY = frame.minY + bottomInset + 58
        let dotsY = buttonY + 72
        let cardTopY = titleY - 70
        let cardBottomY = dotsY + 34
        let cardWidth = min(frame.width - 38, 340)
        let cardHeight = max(250, cardTopY - cardBottomY)
        let cardCenter = CGPoint(x: cx, y: (cardTopY + cardBottomY) / 2)

        addMenuTopChrome(into: page, title: currentMenuOverlayPage.title, titleY: titleY)

        let contentCard = makeGamePanel(size: CGSize(width: cardWidth, height: cardHeight))
        contentCard.position = cardCenter
        page.addChild(contentCard)

        buildMenuOverlayContent(
            into: page,
            center: cardCenter,
            size: CGSize(width: cardWidth, height: cardHeight)
        )

        addMenuPageDots(into: page, centerX: cx, y: dotsY)

        let continueBtn = makeGoldButton(
            size: CGSize(width: min(244, frame.width - 96), height: 54),
            text: "继续游戏",
            name: NodeName.closeMenuButton
        )
        continueBtn.position = CGPoint(x: cx, y: buttonY)
        page.addChild(continueBtn)
    }

    private func buildMenuOverlayContent(into page: SKNode, center: CGPoint, size: CGSize) {
        switch currentMenuOverlayPage {
        case .privacy:
            buildAboutPrivacyContent(into: page, center: center, size: size)
        case .history:
            buildHistoryContent(into: page, center: center, size: size)
        case .achievements:
            buildAchievementsContent(into: page, center: center, size: size)
        case .settings:
            buildSettingsContent(into: page, center: center, size: size)
        }
    }

    private func addMenuTopChrome(into page: SKNode, title: String, titleY: CGFloat) {
        let cx = frame.midX

        let titleGlow = SKShapeNode(ellipseOf: CGSize(width: 190, height: 44))
        titleGlow.fillColor = DesignSystem.Colors.backgroundGlow.withAlphaComponent(0.14)
        titleGlow.strokeColor = .clear
        titleGlow.position = CGPoint(x: cx, y: titleY - 3)
        page.addChild(titleGlow)

        let titleLabel = makeLabel(font: DesignSystem.Fonts.overlayTitleFont(), color: .white)
        titleLabel.text = title
        titleLabel.position = CGPoint(x: cx, y: titleY)
        titleLabel.zPosition = 2
        page.addChild(titleLabel)
    }

    private func addMenuPageDots(into page: SKNode, centerX: CGFloat, y: CGFloat) {
        let pages = MenuOverlayPage.allCases
        let activeIdx = pages.firstIndex(of: currentMenuOverlayPage) ?? 0
        let spacing: CGFloat = 22
        let totalW = CGFloat(pages.count - 1) * spacing

        for i in pages.indices {
            let isActive = i == activeIdx
            let dot = SKShapeNode(circleOfRadius: isActive ? 5.5 : 4)
            dot.fillColor = isActive ? UIColor.white : UIColor.white.withAlphaComponent(0.2)
            dot.strokeColor = isActive ? DesignSystem.Colors.backgroundGlow.withAlphaComponent(0.8) : UIColor.white.withAlphaComponent(0.42)
            dot.lineWidth = 1
            dot.position = CGPoint(x: centerX - totalW / 2 + CGFloat(i) * spacing, y: y)
            dot.zPosition = 2
            page.addChild(dot)
        }
    }

    private func buildSettingsContent(into page: SKNode, center: CGPoint, size: CGSize) {
        let rowWidth = size.width - 28
        let rowHeight: CGFloat = 58
        let rowGap: CGFloat = 12
        let topY = center.y + size.height / 2 - 54

        let rows: [(String, UIColor, String, String, SettingsRowAccessory, String)] = [
            ("🔊", UIColor(hex: "#B84DFF"), "音效", "合成、移动音效", .toggle(isOn: !audioManager.muted), NodeName.soundToggleButton),
            ("♪", UIColor(hex: "#FF941F"), "背景音乐", "游戏背景音乐", .toggle(isOn: !audioManager.musicMuted), NodeName.musicToggleButton),
            ("▣", UIColor(hex: "#20B8FF"), "震动反馈", "合成、移动震动", .toggle(isOn: hapticsEnabled), NodeName.hapticsToggleButton),
            ("⬢", UIColor(hex: "#2B345E"), "黑夜模式", "切换深色背景", .toggle(isOn: nightModeEnabled), NodeName.nightModeToggleButton),
            ("GC", UIColor(hex: "#58C71C"), "Game Center", "查看成就和排行榜", .arrow, NodeName.gameCenterButton),
            ("i", UIColor(hex: "#35A8FF"), "关于 / 隐私", "隐私政策和用户协议", .arrow, NodeName.privacyButton)
        ]

        for (index, row) in rows.enumerated() {
            let node = makeLargeSettingsRow(
                icon: row.0,
                iconColor: row.1,
                title: row.2,
                detail: row.3,
                name: row.5,
                accessory: row.4,
                size: CGSize(width: rowWidth, height: rowHeight)
            )
            node.position = CGPoint(x: center.x, y: topY - CGFloat(index) * (rowHeight + rowGap))
            page.addChild(node)
        }
    }

    private func buildAboutPrivacyContent(into page: SKNode, center: CGPoint, size: CGSize) {
        let logo = makeAboutLogo()
        logo.position = CGPoint(x: center.x, y: center.y + size.height * 0.28)
        page.addChild(logo)

        let gameTitle = makeLabel(font: DesignSystem.Fonts.overlayTitleFont(), color: .white)
        gameTitle.text = "六边形合成"
        gameTitle.fontSize = 34
        gameTitle.position = CGPoint(x: center.x, y: center.y + size.height * 0.12)
        page.addChild(gameTitle)

        let subtitle = makeLabel(font: DesignSystem.Fonts.cardTitleFont(), color: UIColor.white.withAlphaComponent(0.9))
        subtitle.text = "轻松合成 · 快乐益智"
        subtitle.position = CGPoint(x: center.x, y: center.y + size.height * 0.04)
        page.addChild(subtitle)

        let lines = [
            "轻量数字合成，规划空间，合成更高数字。",
            "本游戏仅保存必要的本地游戏数据。"
        ]
        for (index, text) in lines.enumerated() {
            let label = makeLabel(font: DesignSystem.Fonts.cardSubtitleFont(), color: UIColor.white.withAlphaComponent(0.92))
            label.horizontalAlignmentMode = .left
            label.fontSize = 13
            label.text = text
            label.position = CGPoint(x: center.x - size.width / 2 + 34, y: center.y - 18 - CGFloat(index) * 34)
            label.zPosition = 20
            page.addChild(label)
        }

        let rowSize = CGSize(width: size.width - 34, height: 52)
        let privacy = makeSmallLinkRow(icon: "▣", iconColor: UIColor(hex: "#FF8A1D"), title: "隐私政策", name: NodeName.privacyPolicyButton, size: rowSize)
        privacy.position = CGPoint(x: center.x, y: center.y - size.height / 2 + 104)
        privacy.zPosition = 30
        page.addChild(privacy)

        let terms = makeSmallLinkRow(icon: "▤", iconColor: UIColor(hex: "#C8D51B"), title: "用户协议", name: NodeName.termsButton, size: rowSize)
        terms.position = CGPoint(x: center.x, y: center.y - size.height / 2 + 44)
        terms.zPosition = 30
        page.addChild(terms)
    }

    private func buildHistoryContent(into page: SKNode, center: CGPoint, size: CGSize) {
        let snapshot = statsStore.snapshot()
        let topY = center.y + size.height / 2 - 38

        let tabs = makeHistoryTabs()
        tabs.position = CGPoint(x: center.x, y: topY)
        page.addChild(tabs)

        let stats = makeGameStatsCard(snapshot: snapshot)
        stats.position = CGPoint(x: center.x, y: topY - 74)
        page.addChild(stats)

        let listStartY = topY - 136
        if snapshot.recentGames.isEmpty {
            let empty = makeLabel(font: DesignSystem.Fonts.cardTitleFont(), color: DesignSystem.Colors.textSecondary)
            empty.text = "还没有历史记录，先玩几局再回来看看"
            empty.position = CGPoint(x: center.x, y: listStartY - 42)
            page.addChild(empty)
        } else {
            for (index, game) in snapshot.recentGames.prefix(5).enumerated() {
                let row = makeGameHistoryRow(game: game, rank: index + 1)
                row.position = CGPoint(x: center.x, y: listStartY - CGFloat(index) * 58)
                row.setScale(0.96)
                page.addChild(row)
            }
        }
    }

    private func buildAchievementsContent(into page: SKNode, center: CGPoint, size: CGSize) {
        let progress = gameCenterService.progressList()
        let unlocked = progress.filter { $0.unlockedAt != nil }.count
        let topY = center.y + size.height / 2 - 46
        let progressCard = makeAchievementProgressCard(unlocked: unlocked, total: max(progress.count, 48))
        progressCard.position = CGPoint(x: center.x, y: topY)
        page.addChild(progressCard)

        let listStartY = topY - 78
        for (index, item) in progress.prefix(7).enumerated() {
            let row = makeAchievementRow(progress: item)
            row.position = CGPoint(x: center.x, y: listStartY - CGFloat(index) * 48)
            row.setScale(1.02)
            page.addChild(row)
        }
    }

    private func buildSettingsContent(into page: SKNode, center: CGPoint) {
        let soundRow = makeGameSettingsRow(
            icon: "🔊",
            title: "音效",
            detail: audioManager.muted ? "已关闭" : "已开启",
            name: NodeName.soundToggleButton,
            isActive: !audioManager.muted
        )
        soundRow.position = CGPoint(x: center.x, y: center.y + 58)
        page.addChild(soundRow)

        // 隐私说明行
        let privacyRow = makeGameSettingsRow(
            icon: "🛡️",
            title: "隐私说明",
            detail: "本地数据与 Game Center",
            name: NodeName.privacyButton,
            isActive: false
        )
        privacyRow.position = CGPoint(x: center.x, y: center.y - 8)
        page.addChild(privacyRow)
    }

    private func makeAchievementRow(progress: AchievementProgress) -> SKNode {
        let isUnlocked = progress.unlockedAt != nil
        let row = SKNode()

        // 整行背景
        let bg = SKShapeNode(rectOf: CGSize(width: 292, height: 44), cornerRadius: 14)
        bg.fillColor = isUnlocked
            ? DesignSystem.Colors.goldWarm.withAlphaComponent(0.14)
            : DesignSystem.Colors.glassCardBg
        bg.strokeColor = isUnlocked
            ? DesignSystem.Colors.goldWarm.withAlphaComponent(0.38)
            : DesignSystem.Colors.separator
        bg.lineWidth = 1
        row.addChild(bg)

        // 成就图标背景
        let iconBg = SKShapeNode(circleOfRadius: 16)
        iconBg.fillColor = isUnlocked
            ? DesignSystem.Colors.goldWarm.withAlphaComponent(0.28)
            : DesignSystem.Colors.textMuted.withAlphaComponent(0.2)
        iconBg.strokeColor = .clear
        iconBg.position = CGPoint(x: -118, y: 0)
        row.addChild(iconBg)

        // 成就图标文字
        let iconLabel = makeLabel(font: .systemFont(ofSize: 12), color: isUnlocked ? DesignSystem.Colors.goldAccent : DesignSystem.Colors.textMuted)
        iconLabel.text = isUnlocked ? "★" : "☆"
        iconLabel.position = CGPoint(x: -118, y: 0)
        row.addChild(iconLabel)

        // 标题
        let title = makeLabel(font: DesignSystem.Fonts.cardTitleFont(), color: isUnlocked ? .white : DesignSystem.Colors.textMuted)
        title.horizontalAlignmentMode = .left
        title.text = progress.definition.title
        title.position = CGPoint(x: -90, y: 8)
        row.addChild(title)

        // 描述
        let detail = makeLabel(font: DesignSystem.Fonts.cardSubtitleFont(), color: DesignSystem.Colors.textMuted)
        detail.horizontalAlignmentMode = .left
        detail.text = progress.definition.detail
        detail.position = CGPoint(x: -90, y: -10)
        row.addChild(detail)

        // 右侧状态
        let stateLabel = makeLabel(font: DesignSystem.Fonts.badgeFont(), color: isUnlocked ? DesignSystem.Colors.goldAccent : DesignSystem.Colors.textMuted)
        stateLabel.horizontalAlignmentMode = .right
        if isUnlocked {
            stateLabel.text = "✓"
        } else {
            stateLabel.text = "..."
        }
        stateLabel.position = CGPoint(x: 130, y: 0)
        row.addChild(stateLabel)

        return row
    }

    private func buildMenuPrivacyContent(into page: SKNode, center: CGPoint) {
        let cardWidth: CGFloat = 296

        let privacyCard = SKShapeNode(rectOf: CGSize(width: cardWidth, height: 184), cornerRadius: 18)
        privacyCard.fillColor = DesignSystem.Colors.glassCardBg
        privacyCard.strokeColor = DesignSystem.Colors.glassCardStroke
        privacyCard.lineWidth = 1
        privacyCard.position = CGPoint(x: center.x, y: center.y + 24)
        page.addChild(privacyCard)

        let privacyIcon = makeLabel(font: .systemFont(ofSize: 18), color: .white)
        privacyIcon.text = "🛡️"
        privacyIcon.position = CGPoint(x: center.x - 118, y: center.y + 82)
        page.addChild(privacyIcon)

        let privacyTitle = makeLabel(font: DesignSystem.Fonts.cardTitleFont(), color: .white)
        privacyTitle.horizontalAlignmentMode = .left
        privacyTitle.text = "隐私说明"
        privacyTitle.position = CGPoint(x: center.x - 90, y: center.y + 86)
        page.addChild(privacyTitle)

        let privacyDesc = makeLabel(font: DesignSystem.Fonts.cardSubtitleFont(), color: DesignSystem.Colors.textMuted)
        privacyDesc.horizontalAlignmentMode = .left
        privacyDesc.text = "游戏记录、最高分和音效设置保存在本机。\n启用 Game Center 时，只提交排行榜分数\n和成就进度。\n应用不采集定位、通讯录或广告追踪数据。"
        privacyDesc.numberOfLines = 4
        privacyDesc.position = CGPoint(x: center.x - 90, y: center.y + 42)
        page.addChild(privacyDesc)
    }

    private func buildMenuOverlayFooter(into page: SKNode, center: CGPoint) {
        let dots = makeLabel(font: DesignSystem.Fonts.hudSmallFont(), color: DesignSystem.Colors.textDark)
        dots.alpha = 0.48
        dots.text = MenuOverlayPage.allCases.map { $0 == currentMenuOverlayPage ? "●" : "○" }.joined(separator: "  ")
        dots.position = CGPoint(x: center.x, y: center.y + 44)
        page.addChild(dots)

        let closeButton = makeButton(
            size: CGSize(width: 216, height: DesignSystem.Layout.modalButtonHeight),
            fillColor: DesignSystem.Colors.buttonBackground,
            text: "继续游戏",
            textColor: .white,
            name: NodeName.closeMenuButton
        )
        closeButton.position = CGPoint(x: center.x, y: center.y)
        page.addChild(closeButton)
    }

    private func showNextMenuOverlayPage() {
        guard let index = MenuOverlayPage.allCases.firstIndex(of: currentMenuOverlayPage),
              index < MenuOverlayPage.allCases.index(before: MenuOverlayPage.allCases.endIndex) else { return }
        currentMenuOverlayPage = MenuOverlayPage.allCases[MenuOverlayPage.allCases.index(after: index)]
        rebuildOverlayPage(for: .menu)
    }

    private func showPreviousMenuOverlayPage() {
        guard let index = MenuOverlayPage.allCases.firstIndex(of: currentMenuOverlayPage),
              index > MenuOverlayPage.allCases.startIndex else { return }
        currentMenuOverlayPage = MenuOverlayPage.allCases[MenuOverlayPage.allCases.index(before: index)]
        rebuildOverlayPage(for: .menu)
    }

    private func previousMenuOverlayTitle() -> String {
        guard let index = MenuOverlayPage.allCases.firstIndex(of: currentMenuOverlayPage),
              index > MenuOverlayPage.allCases.startIndex else { return "" }
        return MenuOverlayPage.allCases[MenuOverlayPage.allCases.index(before: index)].title
    }

    private func nextMenuOverlayTitle() -> String {
        guard let index = MenuOverlayPage.allCases.firstIndex(of: currentMenuOverlayPage),
              index < MenuOverlayPage.allCases.index(before: MenuOverlayPage.allCases.endIndex) else { return "" }
        return MenuOverlayPage.allCases[MenuOverlayPage.allCases.index(after: index)].title
    }

    private func buildSettingsPage(into page: SKNode) {
        let cx = frame.midX
        let topInset = max(view?.safeAreaInsets.top ?? 44, 44)
        let bottomInset = max(view?.safeAreaInsets.bottom ?? 24, 24)
        let titleY = frame.maxY - topInset - 70

        let titleGlow = SKShapeNode(ellipseOf: CGSize(width: 154, height: 42))
        titleGlow.fillColor = DesignSystem.Colors.backgroundGlow.withAlphaComponent(0.16)
        titleGlow.strokeColor = .clear
        titleGlow.position = CGPoint(x: cx, y: titleY - 2)
        page.addChild(titleGlow)

        let title = makeLabel(font: DesignSystem.Fonts.overlayTitleFont(), color: DesignSystem.Colors.menuTitleGold)
        title.text = "设置"
        title.position = CGPoint(x: cx, y: titleY)
        title.zPosition = 2
        page.addChild(title)

        let closeBtnY = frame.minY + bottomInset + 58
        let cardTopY = titleY - 86
        let cardBottomY = closeBtnY + 86
        let cardHeight = max(230, cardTopY - cardBottomY)
        let cardWidth = min(frame.width - 36, 336)
        let cardCenterY = (cardTopY + cardBottomY) / 2
        let contentCard = makeGlassCard(size: CGSize(width: cardWidth, height: cardHeight))
        contentCard.position = CGPoint(x: cx, y: cardCenterY)
        page.addChild(contentCard)

        let rowWidth = cardWidth - 28
        let rowGap: CGFloat = 18
        let rowHeight: CGFloat = 80
        let firstRowY = cardCenterY + rowGap / 2 + rowHeight / 2
        let secondRowY = cardCenterY - rowGap / 2 - rowHeight / 2

        let soundRow = makeLargeSettingsRow(
            icon: "🔊",
            iconColor: UIColor(hex: "#B84DFF"),
            title: "音效",
            detail: "合成、移动音效",
            name: NodeName.soundToggleButton,
            accessory: .toggle(isOn: !audioManager.muted),
            size: CGSize(width: rowWidth, height: rowHeight)
        )
        soundRow.position = CGPoint(x: cx, y: firstRowY)
        page.addChild(soundRow)

        let privacyRow = makeLargeSettingsRow(
            icon: "🛡️",
            iconColor: UIColor(hex: "#FF8A1D"),
            title: "隐私政策",
            detail: "本地数据与 Game Center",
            name: NodeName.privacyButton,
            accessory: .arrow,
            size: CGSize(width: rowWidth, height: rowHeight)
        )
        privacyRow.position = CGPoint(x: cx, y: secondRowY)
        page.addChild(privacyRow)

        let closeButton = makeGoldButton(
            size: CGSize(width: min(244, frame.width - 96), height: 54),
            text: "继续游戏",
            name: NodeName.closeSettingsButton
        )
        closeButton.position = CGPoint(x: cx, y: closeBtnY)
        page.addChild(closeButton)
    }

    private func buildPrivacyPage(into page: SKNode) {
        let cx = frame.midX
        let topInset = max(view?.safeAreaInsets.top ?? 44, 44)
        let bottomInset = max(view?.safeAreaInsets.bottom ?? 24, 24)
        let topY = frame.maxY - topInset - 56

        // 标题
        let titleBar = SKShapeNode(rectOf: CGSize(width: 148, height: 36), cornerRadius: 18)
        titleBar.fillColor = DesignSystem.Colors.goldWarm.withAlphaComponent(0.12)
        titleBar.strokeColor = DesignSystem.Colors.goldWarm.withAlphaComponent(0.28)
        titleBar.lineWidth = 1.5
        titleBar.position = CGPoint(x: cx, y: topY)
        page.addChild(titleBar)

        let title = makeLabel(font: DesignSystem.Fonts.overlayTitleFont(), color: DesignSystem.Colors.menuTitleGold)
        title.text = "隐私说明"
        title.position = CGPoint(x: cx, y: topY)
        title.zPosition = 2
        page.addChild(title)

        // 内容玻璃卡片
        let cardCenterY = topY - 148
        let contentCard = makeGlassCard(size: CGSize(width: 316, height: 220))
        contentCard.position = CGPoint(x: cx, y: cardCenterY)
        page.addChild(contentCard)

        let lines = [
            "游戏记录、最高分和音效设置保存在本机。",
            "启用 Game Center 时，",
            "只提交排行榜分数和成就进度。",
            "应用不采集定位、通讯录或第三方广告追踪数据。"
        ]

        for (index, line) in lines.enumerated() {
            let label = makeLabel(font: DesignSystem.Fonts.cardSubtitleFont(), color: DesignSystem.Colors.textSecondary)
            label.horizontalAlignmentMode = .left
            label.text = line
            label.position = CGPoint(x: cx - 130, y: cardCenterY + 72 - CGFloat(index) * 36)
            page.addChild(label)
        }

        // 底部按钮
        let backBtnY = frame.minY + bottomInset + 58
        let backButton = makeGoldButton(
            size: CGSize(width: 180, height: 48),
            text: "返回",
            name: NodeName.backToSettingsButton
        )
        backButton.position = CGPoint(x: cx, y: backBtnY)
        page.addChild(backButton)
    }

    private func showPolicyDialog() {
        showInfoDialog(
            title: "隐私政策",
            lines: [
                "我们重视你的隐私。本游戏仅为提供游戏体验而处理必要数据。",
                "本地数据：最高分、历史记录、棋盘快照和音效设置会保存在你的设备上。",
                "Game Center：当你启用 Apple Game Center 时，游戏会提交排行榜分数和成就进度。",
                "我们不采集定位、通讯录、照片、麦克风、摄像头或广告追踪数据。",
                "我们不出售、出租或交易你的个人信息。",
                "你可以不登录 Game Center，仅使用本地单机功能。",
                "如删除本应用，本地保存的数据也会随应用数据一并移除。"
            ]
        )
    }

    private func showTermsDialog() {
        showInfoDialog(
            title: "用户协议",
            lines: [
                "欢迎使用本游戏。继续使用即表示你理解并同意本协议。",
                "本游戏仅供个人娱乐使用，请遵守适用法律法规和 Apple 平台规则。",
                "你不得通过作弊、篡改、自动化脚本或其他异常方式影响排行榜和成就。",
                "Game Center 排行榜、成就和账号能力由 Apple 提供，并受 Apple 条款约束。",
                "游戏内容、界面和音频等资源归开发者或相关权利方所有。",
                "我们可能随版本更新调整玩法、界面、数据展示和服务能力。",
                "如你不同意本协议，可停止使用并删除本应用。"
            ]
        )
    }

    private func showInfoDialog(title: String, lines: [String]) {
        infoDialogNode?.removeFromParent()

        let root = SKNode()
        root.zPosition = 1000

        let scrim = SKShapeNode(rectOf: frame.size)
        scrim.fillColor = UIColor.black.withAlphaComponent(0.52)
        scrim.strokeColor = .clear
        scrim.position = CGPoint(x: frame.midX, y: frame.midY)
        root.addChild(scrim)

        let panelSize = CGSize(width: min(frame.width - 40, 324), height: min(frame.height - 160, 470))
        let panel = makeGamePanel(size: panelSize)
        panel.position = CGPoint(x: frame.midX, y: frame.midY + 12)
        root.addChild(panel)

        let titleLabel = makeLabel(font: DesignSystem.Fonts.overlayTitleFont(), color: .white)
        titleLabel.fontSize = 26
        titleLabel.text = title
        titleLabel.position = CGPoint(x: frame.midX, y: panel.position.y + panelSize.height / 2 - 44)
        root.addChild(titleLabel)

        let startY = panel.position.y + panelSize.height / 2 - 92
        for (index, line) in lines.enumerated() {
            let label = makeLabel(font: DesignSystem.Fonts.cardSubtitleFont(), color: UIColor.white.withAlphaComponent(0.9))
            label.horizontalAlignmentMode = .left
            label.fontSize = 12
            label.numberOfLines = 2
            label.preferredMaxLayoutWidth = panelSize.width - 54
            label.text = line
            label.position = CGPoint(
                x: panel.position.x - panelSize.width / 2 + 28,
                y: startY - CGFloat(index) * 42
            )
            root.addChild(label)
        }

        let okButton = makeGoldButton(
            size: CGSize(width: 150, height: 46),
            text: "知道了",
            name: NodeName.infoDialogCloseButton
        )
        okButton.position = CGPoint(x: frame.midX, y: panel.position.y - panelSize.height / 2 + 38)
        root.addChild(okButton)

        infoDialogNode = root
        if let overlayRoot {
            overlayRoot.addChild(root)
        } else {
            addChild(root)
        }
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let node = atPoint(location)

        var current: SKNode? = node
        while let candidate = current {
            switch candidate.name {
            case NodeName.infoDialogCloseButton:
                audioManager.playButton()
                infoDialogNode?.removeFromParent()
                infoDialogNode = nil
                return
            case NodeName.menuHudButton:
                audioManager.playButton()
                guard scenePhase == .playing else { return }
                currentMenuOverlayPage = .settings
                pushOverlay(phase: .menu)
                return
            case NodeName.restartButton:
                audioManager.playButton()
                startNewGame()
                return
            case NodeName.hintButton:
                audioManager.playButton()
                showHintPulse()
                return
            case NodeName.closeHistoryButton:
                audioManager.playButton()
                closeAllOverlays()
                return
            case NodeName.menuHistoryButton:
                audioManager.playButton()
                pushOverlay(phase: .history)
                return
            case NodeName.menuSettingsButton:
                audioManager.playButton()
                pushOverlay(phase: .settings)
                return
            case NodeName.closeMenuButton:
                audioManager.playButton()
                closeAllOverlays()
                return
            case NodeName.soundToggleButton:
                audioManager.toggleMute()
                rebuildOverlayPage(for: scenePhase)
                return
            case NodeName.musicToggleButton:
                audioManager.toggleBackgroundMusic()
                rebuildOverlayPage(for: scenePhase)
                return
            case NodeName.hapticsToggleButton:
                hapticsEnabled.toggle()
                UserDefaults.standard.set(hapticsEnabled, forKey: "settings.hapticsEnabled")
                playImpact(.light)
                rebuildOverlayPage(for: scenePhase)
                return
            case NodeName.nightModeToggleButton:
                nightModeEnabled.toggle()
                UserDefaults.standard.set(nightModeEnabled, forKey: "settings.nightModeEnabled")
                backgroundTextureCache.removeAll()
                layoutBackground(size: frame.size)
                rebuildOverlayPage(for: scenePhase)
                return
            case NodeName.gameCenterButton:
                audioManager.playButton()
                gameCenterService.presentDashboard()
                return
            case NodeName.leaderboardButton:
                audioManager.playButton()
                gameCenterService.presentLeaderboard()
                return
            case NodeName.gameCenterAchievementsButton:
                audioManager.playButton()
                gameCenterService.presentAchievements()
                return
            case NodeName.privacyPolicyButton:
                audioManager.playButton()
                showPolicyDialog()
                return
            case NodeName.termsButton:
                audioManager.playButton()
                showTermsDialog()
                return
            case NodeName.aboutButton:
                audioManager.playButton()
                pushOverlay(phase: .about)
                return
            case NodeName.privacyButton:
                audioManager.playButton()
                if scenePhase == .menu {
                    currentMenuOverlayPage = .privacy
                    rebuildOverlayPage(for: .menu)
                } else {
                    pushOverlay(phase: .privacy)
                }
                return
            case NodeName.backToSettingsButton:
                audioManager.playButton()
                popOverlay()
                return
            case NodeName.closeSettingsButton:
                audioManager.playButton()
                closeAllOverlays()
                return
            default:
                current = candidate.parent
            }
        }
    }

    private func showHintPulse() {
        guard remainingHints > 0 else {
            playImpact(.light)
            return
        }
        remainingHints -= 1
        updateHintBadge()

        let candidates = GameModel.visualPositions.filter { position in
            guard let tile = model.tile(at: position) else { return false }
            return MoveDirection.allCases.contains { direction in
                let neighbor = GameModel.neighbor(from: position, direction: direction)
                guard let other = model.tile(at: neighbor) else { return false }
                return Tile.canMerge(tile, other)
            }
        }

        guard let position = candidates.randomElement() else {
            playImpact(.light)
            return
        }

        let scenePosition = gridNode.convert(positionForGrid(position), to: self)
        playMilestoneEffect(at: scenePosition, value: model.tile(at: position)?.value ?? 3)
    }

    private func playImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    // MARK: - Node Factory

    private func makeLabel(font: UIFont, color: UIColor) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: font.fontName)
        label.fontSize = font.pointSize
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        return label
    }

    private func makeButton(
        size: CGSize,
        fillColor: UIColor,
        text: String,
        textColor: UIColor,
        name: String
    ) -> SKShapeNode {
        let button = SKShapeNode(rectOf: size, cornerRadius: size.height / 2)
        button.fillColor = fillColor
        button.strokeColor = UIColor.white.withAlphaComponent(0.42)
        button.lineWidth = 2
        button.name = name

        // 顶部高光条（更厚更有质感）
        let shineHeight = max(5, size.height * 0.14)
        let shine = SKShapeNode(
            rectOf: CGSize(width: size.width * 0.82, height: shineHeight),
            cornerRadius: shineHeight / 2
        )
        shine.fillColor = UIColor.white.withAlphaComponent(0.28)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: 0, y: size.height * 0.3)
        shine.name = name
        button.addChild(shine)

        // 文字
        let label = makeLabel(font: DesignSystem.Fonts.buttonFont(), color: textColor)
        if size.height < 34 {
            label.fontSize = DesignSystem.Fonts.hudSmallFont().pointSize
        }
        label.text = text
        label.name = name
        label.position = CGPoint(x: 0, y: -1)
        button.addChild(label)

        return button
    }

    private func makeIconButton(
        diameter: CGFloat,
        fillColor: UIColor,
        icon: String,
        name: String
    ) -> SKShapeNode {
        let button = SKShapeNode(circleOfRadius: diameter / 2)
        button.fillColor = fillColor
        button.strokeColor = UIColor.white.withAlphaComponent(0.48)
        button.lineWidth = 2
        button.name = name

        // 顶部高光（椭圆）
        let shine = SKShapeNode(ellipseOf: CGSize(width: diameter * 0.5, height: diameter * 0.18))
        shine.fillColor = UIColor.white.withAlphaComponent(0.32)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: -diameter * 0.06, y: diameter * 0.18)
        shine.name = name
        button.addChild(shine)

        // 齿轮图标（用 SF Symbol 渲染成图片，再画出来）
        if #available(iOS 13.0, *), icon == "⚙" {
            let config = UIImage.SymbolConfiguration(pointSize: diameter * 0.38, weight: .medium)
            if let gearImage = UIImage(systemName: "gearshape.fill", withConfiguration: config)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                let imageNode = SKSpriteNode(texture: SKTexture(image: gearImage))
                imageNode.size = CGSize(width: diameter * 0.5, height: diameter * 0.5)
                imageNode.position = CGPoint(x: 0, y: -1)
                imageNode.name = name
                imageNode.zPosition = 1
                button.addChild(imageNode)
            } else {
                let label = makeLabel(font: DesignSystem.Fonts.modalValueFont(), color: .white)
                label.fontSize = diameter * 0.42
                label.text = icon
                label.name = name
                label.position = CGPoint(x: 0, y: -1)
                button.addChild(label)
            }
        } else {
            let label = makeLabel(font: DesignSystem.Fonts.modalValueFont(), color: .white)
            label.fontSize = diameter * 0.42
            label.text = icon
            label.name = name
            label.position = CGPoint(x: 0, y: -1)
            button.addChild(label)
        }

        return button
    }

    /// 游戏化设置行（带图标 + 状态指示器）
    private func makeGameSettingsRow(
        icon: String,
        title: String,
        detail: String,
        name: String,
        isActive: Bool
    ) -> SKNode {
        let rowNode = SKNode()

        // 整行背景
        let rowBg = SKShapeNode(rectOf: CGSize(width: 296, height: 50), cornerRadius: 16)
        rowBg.fillColor = DesignSystem.Colors.glassCardBg
        rowBg.strokeColor = isActive
            ? DesignSystem.Colors.goldWarm.withAlphaComponent(0.35)
            : DesignSystem.Colors.separator
        rowBg.lineWidth = 1
        rowBg.name = name
        rowBg.zPosition = 0
        rowNode.addChild(rowBg)

        // 左侧图标背景圆
        let iconBg = SKShapeNode(circleOfRadius: 16)
        iconBg.fillColor = DesignSystem.Colors.goldWarm.withAlphaComponent(isActive ? 0.22 : 0.12)
        iconBg.strokeColor = .clear
        iconBg.position = CGPoint(x: -116, y: 0)
        iconBg.zPosition = 1
        rowNode.addChild(iconBg)

        // 图标
        let iconLabel = makeLabel(font: .systemFont(ofSize: 14), color: .white)
        iconLabel.text = icon
        iconLabel.position = CGPoint(x: -116, y: -1)
        iconLabel.zPosition = 2
        rowNode.addChild(iconLabel)

        // 标题
        let titleLabel = makeLabel(font: DesignSystem.Fonts.cardTitleFont(), color: .white)
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.text = title
        titleLabel.position = CGPoint(x: -86, y: 5)
        titleLabel.zPosition = 1
        rowNode.addChild(titleLabel)

        // 副标题
        let detailLabel = makeLabel(font: DesignSystem.Fonts.cardSubtitleFont(), color: DesignSystem.Colors.textSecondary)
        detailLabel.horizontalAlignmentMode = .left
        detailLabel.text = detail
        detailLabel.position = CGPoint(x: -86, y: -11)
        detailLabel.zPosition = 1
        rowNode.addChild(detailLabel)

        // 右侧状态指示圆点
        let statusDot = SKShapeNode(circleOfRadius: 5)
        statusDot.fillColor = isActive
            ? UIColor(hex: "#32D74B")
            : DesignSystem.Colors.textMuted
        statusDot.strokeColor = .clear
        statusDot.position = CGPoint(x: 124, y: 0)
        statusDot.zPosition = 1
        rowNode.addChild(statusDot)

        return rowNode
    }

    private enum SettingsRowAccessory {
        case toggle(isOn: Bool)
        case arrow
    }

    private func makeLargeSettingsRow(
        icon: String,
        iconColor: UIColor,
        title: String,
        detail: String,
        name: String,
        accessory: SettingsRowAccessory,
        size: CGSize
    ) -> SKNode {
        let rowNode = SKNode()

        let rowBg = SKShapeNode(rectOf: size, cornerRadius: 18)
        rowBg.fillColor = UIColor(hex: "#1466D6").withAlphaComponent(0.72)
        rowBg.strokeColor = UIColor.white.withAlphaComponent(0.22)
        rowBg.lineWidth = 1.4
        rowBg.name = name
        rowBg.zPosition = 0
        rowNode.addChild(rowBg)

        let shine = SKShapeNode(rectOf: CGSize(width: size.width - 18, height: 1.5), cornerRadius: 0.75)
        shine.fillColor = UIColor.white.withAlphaComponent(0.18)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: 0, y: size.height / 2 - 5)
        shine.name = name
        shine.zPosition = 1
        rowNode.addChild(shine)

        let iconBoxSize = CGSize(width: 56, height: 56)
        let iconX = -size.width / 2 + 42
        let iconBox = SKShapeNode(rectOf: iconBoxSize, cornerRadius: 14)
        iconBox.fillColor = iconColor
        iconBox.strokeColor = UIColor.white.withAlphaComponent(0.38)
        iconBox.lineWidth = 1.2
        iconBox.position = CGPoint(x: iconX, y: 0)
        iconBox.name = name
        iconBox.zPosition = 2
        rowNode.addChild(iconBox)

        let iconHighlight = SKShapeNode(rectOf: CGSize(width: 42, height: 10), cornerRadius: 5)
        iconHighlight.fillColor = UIColor.white.withAlphaComponent(0.22)
        iconHighlight.strokeColor = .clear
        iconHighlight.position = CGPoint(x: iconX, y: 17)
        iconHighlight.name = name
        iconHighlight.zPosition = 3
        rowNode.addChild(iconHighlight)

        let iconLabel = makeLabel(font: .systemFont(ofSize: 26, weight: .bold), color: .white)
        iconLabel.text = icon
        iconLabel.name = name
        iconLabel.position = CGPoint(x: iconX, y: -1)
        iconLabel.zPosition = 4
        rowNode.addChild(iconLabel)

        let textX = -size.width / 2 + 86
        let titleLabel = makeLabel(font: DesignSystem.Fonts.cardTitleFont(), color: .white)
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.fontSize = 18
        titleLabel.text = title
        titleLabel.name = name
        titleLabel.position = CGPoint(x: textX, y: 12)
        titleLabel.zPosition = 2
        rowNode.addChild(titleLabel)

        let detailLabel = makeLabel(font: DesignSystem.Fonts.cardSubtitleFont(), color: DesignSystem.Colors.textSecondary)
        detailLabel.horizontalAlignmentMode = .left
        detailLabel.fontSize = 13
        detailLabel.text = detail
        detailLabel.name = name
        detailLabel.position = CGPoint(x: textX, y: -13)
        detailLabel.zPosition = 2
        rowNode.addChild(detailLabel)

        switch accessory {
        case .toggle(let isOn):
            let toggle = makeSettingsToggle(isOn: isOn, name: name)
            toggle.position = CGPoint(x: size.width / 2 - 48, y: 0)
            rowNode.addChild(toggle)
        case .arrow:
            let arrow = makeLabel(font: .systemFont(ofSize: 30, weight: .bold), color: UIColor.white.withAlphaComponent(0.88))
            arrow.text = "›"
            arrow.name = name
            arrow.position = CGPoint(x: size.width / 2 - 28, y: 0)
            arrow.zPosition = 3
            rowNode.addChild(arrow)
        }

        return rowNode
    }

    private func makeSettingsToggle(isOn: Bool, name: String) -> SKNode {
        let node = SKNode()
        let size = CGSize(width: 58, height: 34)
        let track = SKShapeNode(rectOf: size, cornerRadius: size.height / 2)
        track.fillColor = isOn ? UIColor(hex: "#35D438") : UIColor(hex: "#39578C")
        track.strokeColor = UIColor.white.withAlphaComponent(0.3)
        track.lineWidth = 1
        track.name = name
        track.zPosition = 2
        node.addChild(track)

        let innerGlow = SKShapeNode(rectOf: CGSize(width: size.width - 8, height: 8), cornerRadius: 4)
        innerGlow.fillColor = UIColor.white.withAlphaComponent(isOn ? 0.26 : 0.12)
        innerGlow.strokeColor = .clear
        innerGlow.position = CGPoint(x: 0, y: 8)
        innerGlow.name = name
        innerGlow.zPosition = 3
        node.addChild(innerGlow)

        let knob = SKShapeNode(circleOfRadius: 15)
        knob.fillColor = .white
        knob.strokeColor = UIColor.black.withAlphaComponent(0.1)
        knob.lineWidth = 1
        knob.position = CGPoint(x: isOn ? 12 : -12, y: 0)
        knob.name = name
        knob.zPosition = 4
        node.addChild(knob)

        return node
    }

    private func makeNextHUDCard(size: CGSize) -> SKShapeNode {
        let cornerRadius = size.height * 0.38
        let card = SKShapeNode(rectOf: size, cornerRadius: cornerRadius)
        card.fillColor = UIColor(hex: "#0D7DE8").withAlphaComponent(0.9)
        card.strokeColor = UIColor(hex: "#8BE9FF").withAlphaComponent(0.72)
        card.lineWidth = 2
        card.zPosition = 29

        let inner = SKShapeNode(rectOf: CGSize(width: size.width - 8, height: size.height - 8), cornerRadius: cornerRadius - 4)
        inner.fillColor = .clear
        inner.strokeColor = UIColor.white.withAlphaComponent(0.14)
        inner.lineWidth = 1
        inner.zPosition = 1
        card.addChild(inner)

        let shine = SKShapeNode(
            rectOf: CGSize(width: size.width - 18, height: 10),
            cornerRadius: 5
        )
        shine.fillColor = UIColor.white.withAlphaComponent(0.24)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: 0, y: size.height * 0.28)
        shine.zPosition = 2
        card.addChild(shine)

        return card
    }

    private func makeHUDCard(size: CGSize) -> SKShapeNode {
        let cornerRadius = min(22, size.height * 0.28)
        let card = SKShapeNode(rectOf: size, cornerRadius: cornerRadius)
        card.fillColor = DesignSystem.Colors.cardBackground
        card.strokeColor = UIColor.white.withAlphaComponent(0.42)
        card.lineWidth = 2
        card.zPosition = 29

        // 顶部高光（精致内高光）
        let shineH = max(4, size.height * 0.13)
        let shine = SKShapeNode(
            rectOf: CGSize(width: size.width - 16, height: shineH),
            cornerRadius: shineH / 2
        )
        shine.fillColor = UIColor.white.withAlphaComponent(0.2)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: 0, y: size.height * 0.3)
        card.addChild(shine)

        return card
    }

    /// 玻璃质感卡片（游戏化 Menu 页面用）
    private func makeGlassCard(size: CGSize) -> SKShapeNode {
        let cornerRadius: CGFloat = 24
        let card = SKShapeNode(rectOf: size, cornerRadius: cornerRadius)
        card.fillColor = DesignSystem.Colors.glassCardBg
        card.strokeColor = DesignSystem.Colors.glassCardStroke
        card.lineWidth = 1.5

        // 底部投影（厚重感）
        let shadow = SKShapeNode(rectOf: size, cornerRadius: cornerRadius)
        shadow.fillColor = UIColor.black.withAlphaComponent(0.32)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -10)
        shadow.zPosition = -1
        card.addChild(shadow)

        // 顶部高光条
        let shineH: CGFloat = 1.5
        let shine = SKShapeNode(rectOf: CGSize(width: size.width - 20, height: shineH), cornerRadius: shineH / 2)
        shine.fillColor = DesignSystem.Colors.glassCardShine
        shine.strokeColor = .clear
        shine.position = CGPoint(x: 0, y: size.height / 2 - 3)
        card.addChild(shine)

        return card
    }

    private func makeGamePanel(size: CGSize) -> SKShapeNode {
        let card = makeGlassCard(size: size)
        card.fillColor = UIColor(hex: "#0F55C5").withAlphaComponent(0.74)
        card.strokeColor = UIColor(hex: "#69C7FF").withAlphaComponent(0.68)
        card.lineWidth = 2

        let inner = SKShapeNode(rectOf: CGSize(width: size.width - 10, height: size.height - 10), cornerRadius: 22)
        inner.fillColor = .clear
        inner.strokeColor = UIColor.white.withAlphaComponent(0.18)
        inner.lineWidth = 1
        inner.zPosition = 2
        card.addChild(inner)

        let glow = SKShapeNode(rectOf: CGSize(width: size.width + 4, height: size.height + 4), cornerRadius: 26)
        glow.fillColor = .clear
        glow.strokeColor = DesignSystem.Colors.backgroundGlow.withAlphaComponent(0.28)
        glow.lineWidth = 4
        glow.zPosition = -2
        card.addChild(glow)

        return card
    }

    private func makeCoinPill() -> SKNode {
        let root = SKNode()
        let size = CGSize(width: 142, height: 38)
        let bg = SKShapeNode(rectOf: size, cornerRadius: 19)
        bg.fillColor = UIColor(hex: "#123F9C").withAlphaComponent(0.92)
        bg.strokeColor = UIColor.white.withAlphaComponent(0.32)
        bg.lineWidth = 1.4
        root.addChild(bg)

        let coin = SKShapeNode(circleOfRadius: 18)
        coin.fillColor = DesignSystem.Colors.coinGold
        coin.strokeColor = UIColor.white.withAlphaComponent(0.45)
        coin.lineWidth = 2
        coin.position = CGPoint(x: -51, y: 0)
        root.addChild(coin)

        let star = makeLabel(font: .systemFont(ofSize: 18, weight: .black), color: .white)
        star.text = "★"
        star.position = coin.position
        root.addChild(star)

        let amount = makeLabel(font: DesignSystem.Fonts.cardTitleFont(), color: .white)
        amount.fontSize = 20
        amount.text = "256"
        amount.position = CGPoint(x: 6, y: 0)
        root.addChild(amount)

        let plus = SKShapeNode(circleOfRadius: 15)
        plus.fillColor = UIColor(hex: "#36D642")
        plus.strokeColor = UIColor.white.withAlphaComponent(0.46)
        plus.lineWidth = 1.5
        plus.position = CGPoint(x: 55, y: 0)
        root.addChild(plus)

        let plusLabel = makeLabel(font: .systemFont(ofSize: 20, weight: .black), color: .white)
        plusLabel.text = "+"
        plusLabel.position = plus.position
        root.addChild(plusLabel)

        return root
    }

    private func makeAboutLogo() -> SKNode {
        let root = SKNode()
        let glow = SKShapeNode(circleOfRadius: 58)
        glow.fillColor = DesignSystem.Colors.backgroundGlow.withAlphaComponent(0.24)
        glow.strokeColor = .clear
        root.addChild(glow)

        let values = [2, 1, 96, 24, 48, 192, 3]
        let offsets = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: -23, y: 13),
            CGPoint(x: 23, y: 13),
            CGPoint(x: -23, y: -13),
            CGPoint(x: 23, y: -13),
            CGPoint(x: 0, y: 26),
            CGPoint(x: 0, y: -26)
        ]
        for (index, value) in values.enumerated() {
            let hex = SKShapeNode(path: hexPath(width: 34))
            hex.fillColor = DesignSystem.Colors.tileBackground(for: value)
            hex.strokeColor = UIColor.white.withAlphaComponent(0.52)
            hex.lineWidth = 2
            hex.position = offsets[index]
            root.addChild(hex)
        }

        return root
    }

    private func makeSmallLinkRow(icon: String, iconColor: UIColor, title: String, name: String, size: CGSize) -> SKNode {
        let row = SKNode()
        row.name = name
        let bg = SKShapeNode(rectOf: size, cornerRadius: 15)
        bg.fillColor = UIColor(hex: "#1265D8").withAlphaComponent(0.82)
        bg.strokeColor = UIColor.white.withAlphaComponent(0.24)
        bg.lineWidth = 1.2
        bg.name = name
        bg.zPosition = 1
        row.addChild(bg)

        let iconBox = SKShapeNode(rectOf: CGSize(width: 34, height: 34), cornerRadius: 10)
        iconBox.fillColor = iconColor
        iconBox.strokeColor = UIColor.white.withAlphaComponent(0.36)
        iconBox.lineWidth = 1
        iconBox.position = CGPoint(x: -size.width / 2 + 32, y: 0)
        iconBox.name = name
        iconBox.zPosition = 2
        row.addChild(iconBox)

        let iconLabel = makeLabel(font: .systemFont(ofSize: 17, weight: .black), color: .white)
        iconLabel.text = icon
        iconLabel.name = name
        iconLabel.position = iconBox.position
        iconLabel.zPosition = 3
        row.addChild(iconLabel)

        let titleLabel = makeLabel(font: DesignSystem.Fonts.cardTitleFont(), color: .white)
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.text = title
        titleLabel.name = name
        titleLabel.position = CGPoint(x: -size.width / 2 + 66, y: 0)
        titleLabel.zPosition = 3
        row.addChild(titleLabel)

        let arrow = makeLabel(font: .systemFont(ofSize: 28, weight: .black), color: .white)
        arrow.text = "›"
        arrow.name = name
        arrow.position = CGPoint(x: size.width / 2 - 24, y: 0)
        arrow.zPosition = 3
        row.addChild(arrow)

        return row
    }

    private func makeHistoryTabs() -> SKNode {
        let root = SKNode()
        let active = makeSmallLinkRow(icon: "🏆", iconColor: DesignSystem.Colors.goldWarm, title: "排行榜", name: NodeName.leaderboardButton, size: CGSize(width: 150, height: 46))
        active.position = CGPoint(x: -78, y: 0)
        active.setScale(0.86)
        root.addChild(active)

        let inactive = makeSmallLinkRow(icon: "◷", iconColor: UIColor(hex: "#7FAAFF"), title: "我的记录", name: NodeName.gameCenterAchievementsButton, size: CGSize(width: 150, height: 46))
        inactive.position = CGPoint(x: 78, y: 0)
        inactive.alpha = 0.72
        inactive.setScale(0.86)
        root.addChild(inactive)

        return root
    }

    private func makeAchievementProgressCard(unlocked: Int, total: Int) -> SKNode {
        let root = SKNode()
        let size = CGSize(width: 300, height: 72)
        let bg = SKShapeNode(rectOf: size, cornerRadius: 20)
        bg.fillColor = UIColor(hex: "#1265D8").withAlphaComponent(0.8)
        bg.strokeColor = UIColor(hex: "#69C7FF").withAlphaComponent(0.48)
        bg.lineWidth = 1.4
        root.addChild(bg)

        let trophy = makeLabel(font: .systemFont(ofSize: 34, weight: .black), color: DesignSystem.Colors.goldAccent)
        trophy.text = "🏆"
        trophy.position = CGPoint(x: -118, y: 0)
        root.addChild(trophy)

        let title = makeLabel(font: DesignSystem.Fonts.cardTitleFont(), color: .white)
        title.horizontalAlignmentMode = .left
        title.text = "已完成 \(unlocked)/\(total)"
        title.position = CGPoint(x: -72, y: 16)
        root.addChild(title)

        let track = SKShapeNode(rectOf: CGSize(width: 130, height: 10), cornerRadius: 5)
        track.fillColor = UIColor.black.withAlphaComponent(0.24)
        track.strokeColor = UIColor.white.withAlphaComponent(0.16)
        track.lineWidth = 1
        track.position = CGPoint(x: -7, y: -14)
        root.addChild(track)

        let ratio = total > 0 ? min(1, CGFloat(unlocked) / CGFloat(total)) : 0
        let fillWidth = max(12, 130 * ratio)
        let fill = SKShapeNode(rectOf: CGSize(width: fillWidth, height: 10), cornerRadius: 5)
        fill.fillColor = DesignSystem.Colors.goldWarm
        fill.strokeColor = .clear
        fill.position = CGPoint(x: -7 - 65 + fillWidth / 2, y: -14)
        root.addChild(fill)

        let chest = makeLabel(font: .systemFont(ofSize: 31, weight: .black), color: DesignSystem.Colors.goldAccent)
        chest.text = "🎁"
        chest.position = CGPoint(x: 122, y: 0)
        root.addChild(chest)

        return root
    }

    /// 金色主按钮（游戏化风格）
    private func makeGoldButton(size: CGSize, text: String, name: String?) -> SKShapeNode {
        let cornerRadius = size.height / 2

        // 主体
        let button = SKShapeNode(rectOf: size, cornerRadius: cornerRadius)
        button.fillColor = DesignSystem.Colors.primaryButtonGold
        button.strokeColor = .clear
        button.name = name
        button.zPosition = 1

        // 顶部高光
        let shineH = max(4, size.height * 0.18)
        let shine = SKShapeNode(rectOf: CGSize(width: size.width - 12, height: shineH), cornerRadius: shineH / 2)
        shine.fillColor = UIColor.white.withAlphaComponent(0.32)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: 0, y: size.height * 0.22)
        shine.zPosition = 2
        shine.name = name

        // 文字
        let label = makeLabel(font: DesignSystem.Fonts.primaryButtonFont(), color: DesignSystem.Colors.primaryButtonDark)
        label.text = text
        label.position = CGPoint(x: 0, y: -size.height * 0.06)
        label.zPosition = 3
        label.name = name

        button.addChild(shine)
        button.addChild(label)

        return button
    }

    private func showAchievementToasts(_ unlocks: [AchievementUnlock]) {
        guard !unlocks.isEmpty else { return }

        achievementToastNode?.removeFromParent()
        let toast = makeAchievementToast(title: unlocks[0].title)
        achievementToastNode = toast
        addChild(toast)

        let wait = SKAction.wait(forDuration: 2.1)
        let fade = SKAction.group([
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.moveBy(x: 0, y: 12, duration: 0.2)
        ])
        toast.run(SKAction.sequence([wait, fade, .removeFromParent()])) { [weak self] in
            self?.achievementToastNode = nil
            self?.showAchievementToasts(Array(unlocks.dropFirst()))
        }
    }

    private func makeAchievementToast(title: String) -> SKNode {
        let toast = SKNode()
        toast.zPosition = 140
        toast.alpha = 0
        toast.position = CGPoint(x: frame.midX, y: frame.maxY - 92)

        let width = min(frame.width - 40, 310)
        let background = SKShapeNode(
            rectOf: CGSize(width: width, height: 54),
            cornerRadius: 18
        )
        background.fillColor = DesignSystem.Colors.achievementBackground
        background.strokeColor = UIColor.white.withAlphaComponent(0.55)
        background.lineWidth = 1
        toast.addChild(background)

        let label = makeLabel(font: DesignSystem.Fonts.achievementFont(), color: DesignSystem.Colors.textLight)
        label.text = "成就达成  \(title)"
        label.position = CGPoint(x: 0, y: -1)
        toast.addChild(label)

        let fadeIn = SKAction.fadeIn(withDuration: 0.16)
        let slide = SKAction.moveBy(x: 0, y: -8, duration: 0.16)
        slide.timingMode = .easeOut
        toast.run(SKAction.group([fadeIn, slide]))

        return toast
    }
}

private enum ScenePhase {
    case playing
    case gameOver
    case history
    case menu
    case settings
    case about
    case privacy
}

private enum MenuOverlayPage: Int, CaseIterable {
    case privacy
    case history
    case achievements
    case settings

    var title: String {
        switch self {
        case .privacy: return "关于 / 隐私"
        case .history: return "历史记录"
        case .achievements: return "成就"
        case .settings: return "设置"
        }
    }
}

private struct TileTextureKey: Hashable {
    let value: Int
    let size: Int
}

private struct BackgroundTextureKey: Hashable {
    let width: Int
    let height: Int
}

private enum NodeName {
    static let cell = "cell"
    static let boardPanel = "boardPanel"
    static let scrim = "scrim"
    static let pageBackground = "pageBackground"
    static let menuHudButton = "menuHudButton"
    static let gameOverHistoryButton = "gameOverHistoryButton"
    static let restartButton = "restartButton"
    static let hintButton = "hintButton"
    static let closeHistoryButton = "closeHistoryButton"
    static let menuHistoryButton = "menuHistoryButton"
    static let menuSettingsButton = "menuSettingsButton"
    static let closeMenuButton = "closeMenuButton"
    static let soundToggleButton = "soundToggleButton"
    static let musicToggleButton = "musicToggleButton"
    static let hapticsToggleButton = "hapticsToggleButton"
    static let nightModeToggleButton = "nightModeToggleButton"
    static let gameCenterButton = "gameCenterButton"
    static let leaderboardButton = "leaderboardButton"
    static let gameCenterAchievementsButton = "gameCenterAchievementsButton"
    static let aboutButton = "aboutButton"
    static let privacyButton = "privacyButton"
    static let privacyPolicyButton = "privacyPolicyButton"
    static let termsButton = "termsButton"
    static let infoDialogCloseButton = "infoDialogCloseButton"
    static let backToSettingsButton = "backToSettingsButton"
    static let closeSettingsButton = "closeSettingsButton"
}
