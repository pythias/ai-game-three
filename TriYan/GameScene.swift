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
    private var achievementToastNode: SKNode?
    private var currentMenuOverlayPage: MenuOverlayPage = .settings
    private var currentGameAchievementIDs: [String] = []

    private var isAnimating = false
    private var scenePhase: ScenePhase = .playing
    private var didRecordCurrentGame = false
    private var mergeStreak = 0
    private var pendingSwipe: SwipeDirection?
    private var remainingHints = 3

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
        nextCardNode = makeHUDCard(size: DesignSystem.Layout.nextCardSize)
        addChild(nextCardNode)

        nextTitleLabel = makeLabel(font: DesignSystem.Fonts.hudLabelFont(), color: DesignSystem.Colors.textDark)
        nextTitleLabel.fontSize = 20
        nextTitleLabel.text = "BEST"
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
        bestValueLabel.fontSize = 26
        bestValueLabel.text = "0"
        bestValueLabel.alpha = 1
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
        let leftInset = max(safeInsets.left, 0)
        let rightInset = max(safeInsets.right, 0)
        let bottomInset = max(safeInsets.bottom, 20)
        let horizontalPadding: CGFloat = 28
        let safeTop = frame.maxY - topInset
        let headerCenterY = safeTop - DesignSystem.Layout.nextCardSize.height / 2 - 10
        let gridSize = DesignSystem.Layout.gridSize(in: view)
        let scoreCenterY = headerCenterY - 108
        let hexHeight = self.hexHeight(width: DesignSystem.Layout.cellSize(gridSize: gridSize))
        let boardHeight = hexHeight + hexHeight * 0.75 * 4
        let boardTop = scoreCenterY - DesignSystem.Layout.scoreCardSize.height / 2 - 34
        let boardCenterY = boardTop - boardHeight / 2
        let bottomButtonY = frame.minY + bottomInset + 48

        layoutBackground(size: frame.size)
        gridNode.position = CGPoint(x: frame.midX, y: boardCenterY)

        let rightCardX = frame.maxX - rightInset - horizontalPadding - 29
        let centerCardX = frame.midX

        menuButton.position = CGPoint(x: rightCardX, y: headerCenterY)

        nextCardNode.position = CGPoint(x: centerCardX, y: headerCenterY)
        nextTitleLabel.position = CGPoint(x: centerCardX, y: headerCenterY + 14)
        nextPreviewNode.position = CGPoint(x: centerCardX - 48, y: headerCenterY - 14)
        bestValueLabel.position = CGPoint(x: centerCardX + 18, y: headerCenterY - 14)

        scoreCardNode.position = CGPoint(x: frame.midX, y: scoreCenterY)
        scoreTitleLabel.position = CGPoint(x: frame.midX, y: scoreCenterY + 24)
        scoreValueLabel.position = CGPoint(x: frame.midX, y: scoreCenterY - 14)

        let buttonGap: CGFloat = 18
        let buttonWidth = min(156, (frame.width - leftInset - rightInset - horizontalPadding * 2 - buttonGap) / 2)
        restartHudButton.position = CGPoint(x: frame.midX - buttonWidth / 2 - buttonGap / 2, y: bottomButtonY)
        hintHudButton.position = CGPoint(x: frame.midX + buttonWidth / 2 + buttonGap / 2, y: bottomButtonY)
        hintBadgeNode.position = CGPoint(x: hintHudButton.position.x + buttonWidth / 2 - 10, y: bottomButtonY + 28)

        layoutGridBackground(gridSize: gridSize)
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
        for position in GameModel.visualPositions {
            let shadow = SKShapeNode(path: hexPath(width: cellSize + 8))
            shadow.fillColor = UIColor.black.withAlphaComponent(0.12)
            shadow.strokeColor = .clear
            shadow.name = NodeName.boardPanel
            shadow.position = pointForGridPosition(position, gridSize: gridSize, cellSize: cellSize)
                .applying(CGAffineTransform(translationX: 0, y: -5))
            shadow.zPosition = -4
            gridNode.addChild(shadow)

            let rim = SKShapeNode(path: hexPath(width: cellSize + 7))
            rim.fillColor = DesignSystem.Colors.boardBackground.withAlphaComponent(0.9)
            rim.strokeColor = UIColor.white.withAlphaComponent(0.22)
            rim.lineWidth = 1
            rim.name = NodeName.boardPanel
            rim.position = pointForGridPosition(position, gridSize: gridSize, cellSize: cellSize)
            rim.zPosition = -3
            gridNode.addChild(rim)

            let cell = SKShapeNode(path: hexPath(width: cellSize - 2))
            cell.fillColor = DesignSystem.Colors.emptyCell.withAlphaComponent(0.56)
            cell.strokeColor = UIColor.white.withAlphaComponent(0.2)
            cell.lineWidth = 1
            cell.name = NodeName.cell
            cell.alpha = 0.92
            cell.zPosition = -1
            cell.position = pointForGridPosition(position, gridSize: gridSize, cellSize: cellSize)
            gridNode.addChild(cell)
        }
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
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                let move = SKAction.move(
                    to: positionForGrid(movement.to),
                    duration: DesignSystem.Animation.moveDuration
                )
                move.timingMode = .easeOut
                node.run(move)
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
        let gridSize = DesignSystem.Layout.gridSize(in: view)
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
        let gridSize = DesignSystem.Layout.gridSize(in: view)
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

        let gridSize = DesignSystem.Layout.gridSize(in: view)
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

    private func hexPath(width: CGFloat) -> CGPath {
        hexPath(width: width, center: .zero)
    }

    private func hexPath(width: CGFloat, center: CGPoint) -> CGPath {
        let radius = width / sqrt(3)
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

    private func tileTexture(value: Int, size: CGFloat) -> SKTexture {
        let key = TileTextureKey(value: value, size: Int(size.rounded()))
        if let cached = tileTextureCache[key] {
            return cached
        }

        let height = hexHeight(width: size)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: height))
        let image = renderer.image { context in
            let cgContext = context.cgContext
            let path = UIBezierPath(cgPath: hexPath(width: size - 2, center: CGPoint(x: size / 2, y: height / 2)))
            let baseColor = DesignSystem.Colors.tileBackground(for: value)
            let highlightColor = DesignSystem.Colors.tileHighlight(for: value)

            let shadowPath = UIBezierPath(cgPath: hexPath(width: size - 1, center: CGPoint(x: size / 2, y: height / 2 + 2)))
            UIColor.black.withAlphaComponent(0.22).setFill()
            shadowPath.fill()

            cgContext.saveGState()
            path.addClip()
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [highlightColor.cgColor, baseColor.cgColor] as CFArray,
                locations: [0, 1]
            ) {
                cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: size * 0.18, y: height * 0.12),
                    end: CGPoint(x: size * 0.85, y: height * 0.9),
                    options: []
                )
            } else {
                baseColor.setFill()
                path.fill()
            }
            cgContext.restoreGState()

            UIColor.black.withAlphaComponent(value <= 3 ? 0.08 : 0.14).setFill()
            let lowerPath = UIBezierPath(cgPath: hexPath(width: size - 2, center: CGPoint(x: size / 2, y: height / 2)))
            cgContext.saveGState()
            lowerPath.addClip()
            cgContext.fill(CGRect(x: 0, y: height * 0.68, width: size, height: height * 0.32))
            cgContext.restoreGState()

            UIColor.white.withAlphaComponent(value <= 3 ? 0.42 : 0.26).setFill()
            UIBezierPath(roundedRect: CGRect(x: size * 0.18, y: height * 0.18, width: size * 0.4, height: max(3, height * 0.05)), cornerRadius: height * 0.025).fill()

            UIColor.white.withAlphaComponent(0.28).setStroke()
            path.lineWidth = 1
            path.stroke()

            UIColor.black.withAlphaComponent(0.18).setStroke()
            let inner = UIBezierPath(cgPath: hexPath(width: size * 0.82, center: CGPoint(x: size / 2, y: height / 2)))
            inner.lineWidth = 1
            inner.stroke()

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
            let shadow = NSShadow()
            shadow.shadowBlurRadius = 3
            shadow.shadowOffset = CGSize(width: 0, height: 2)
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.34)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: DesignSystem.Colors.tileText(for: value),
                .paragraphStyle: paragraph,
                .shadow: shadow
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: 0,
                y: (height - textSize.height) / 2 - height * 0.025,
                width: size,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        tileTextureCache[key] = texture
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
            let colors = [
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

            UIColor.white.withAlphaComponent(0.28).setFill()
            cgContext.fillEllipse(in: CGRect(x: -size.width * 0.22, y: -size.height * 0.12, width: size.width * 0.72, height: size.width * 0.72))

            DesignSystem.Colors.progressFill.withAlphaComponent(0.09).setFill()
            cgContext.fillEllipse(in: CGRect(x: size.width * 0.62, y: size.height * 0.08, width: size.width * 0.52, height: size.width * 0.52))

            UIColor.white.withAlphaComponent(0.16).setStroke()
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
        bestValueLabel.text = formatScore(max(model.score, statsStore.bestScore()))
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

        let gained = result.merges.reduce(0) { $0 + $1.resultValue }
        let label = makeLabel(font: DesignSystem.Fonts.hudValueFont(), color: DesignSystem.Colors.progressFill)
        label.zPosition = 60
        label.text = mergeStreak >= 2 ? "+\(gained)  x\(mergeStreak)" : "+\(gained)"

        if let largestMerge = result.merges.max(by: { $0.resultValue < $1.resultValue }) {
            label.position = gridNode.convert(positionForGrid(largestMerge.at), to: self)
            if largestMerge.resultValue >= 48 {
                playMilestoneEffect(at: label.position, value: largestMerge.resultValue)
            }
        } else {
            label.position = CGPoint(x: frame.midX, y: frame.midY)
        }

        addChild(label)

        let lift = SKAction.moveBy(x: 0, y: 34, duration: 0.38)
        lift.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: 0.34)
        label.run(.sequence([.group([lift, fade]), .removeFromParent()]))

        if mergeStreak >= 3 {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        } else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
        if previewTileValue == -1 {
            return
        }
        nextPreviewNode.removeAllChildren()
        let crown = makeLabel(font: DesignSystem.Fonts.hudValueFont(), color: DesignSystem.Colors.progressFill)
        crown.text = "♛"
        crown.fontSize = 28
        nextPreviewNode.addChild(crown)
        previewTileNode = nil
        previewTileValue = -1

        guard animated else { return }

        let pop = SKAction.scale(to: 1, duration: DesignSystem.Animation.previewDuration)
        pop.timingMode = .easeOut
        crown.setScale(0.78)
        crown.run(pop)
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

    private func makeStatsSummary(snapshot: StatsSnapshot) -> SKNode {
        let root = SKNode()
        let items = [
            ("最高分", formatScore(snapshot.bestScore)),
            ("最高块", "\(snapshot.maxTileEver)"),
            ("局数", "\(snapshot.gamesPlayed)")
        ]

        for (index, item) in items.enumerated() {
            let card = SKShapeNode(rectOf: CGSize(width: 92, height: 54), cornerRadius: 16)
            card.fillColor = DesignSystem.Colors.cardBackground.withAlphaComponent(0.82)
            card.strokeColor = DesignSystem.Colors.cardStroke
            card.lineWidth = 1
            card.position = CGPoint(x: -102 + CGFloat(index) * 102, y: 0)
            root.addChild(card)

            let label = makeLabel(font: DesignSystem.Fonts.hudSmallFont(), color: DesignSystem.Colors.textDark)
            label.text = item.0
            label.alpha = 0.68
            label.position = CGPoint(x: 0, y: 12)
            card.addChild(label)

            let value = makeLabel(font: DesignSystem.Fonts.historyRowTitleFont(), color: DesignSystem.Colors.textDark)
            value.text = item.1
            value.position = CGPoint(x: 0, y: -10)
            card.addChild(value)
        }

        return root
    }

    private func makeHistoryRow(game: GameRecord, rank: Int) -> SKNode {
        let row = SKNode()

        let background = SKShapeNode(
            rectOf: CGSize(width: 292, height: 58),
            cornerRadius: 16
        )
        background.fillColor = DesignSystem.Colors.cardBackground.withAlphaComponent(rank == 1 ? 0.9 : 0.7)
        background.strokeColor = rank == 1 ? DesignSystem.Colors.progressFill.withAlphaComponent(0.52) : DesignSystem.Colors.cardStroke
        background.lineWidth = 1
        row.addChild(background)

        let board = makeHistoryBoardSnapshot(game.boardSnapshot, tileSize: 9, spacing: 2, showValues: false)
        board.position = CGPoint(x: -112, y: 0)
        row.addChild(board)

        let rankLabel = makeLabel(font: DesignSystem.Fonts.historyRowBodyFont(), color: DesignSystem.Colors.textDark)
        rankLabel.text = "#\(rank)"
        rankLabel.alpha = 0.62
        rankLabel.horizontalAlignmentMode = .left
        rankLabel.position = CGPoint(x: -72, y: 12)
        row.addChild(rankLabel)

        let timeLabel = makeLabel(font: DesignSystem.Fonts.historyRowBodyFont(), color: DesignSystem.Colors.textDark)
        timeLabel.horizontalAlignmentMode = .left
        timeLabel.text = historyDateFormatter.string(from: game.playedAt)
        timeLabel.alpha = 0.68
        timeLabel.position = CGPoint(x: -36, y: 12)
        row.addChild(timeLabel)

        let scoreLabel = makeLabel(font: DesignSystem.Fonts.historyRowTitleFont(), color: DesignSystem.Colors.textDark)
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.text = "\(formatScore(game.score)) 分"
        scoreLabel.position = CGPoint(x: -72, y: -12)
        row.addChild(scoreLabel)

        let maxTileLabel = makeLabel(font: DesignSystem.Fonts.historyRowBodyFont(), color: DesignSystem.Colors.textDark)
        maxTileLabel.horizontalAlignmentMode = .right
        maxTileLabel.text = "最高 \(game.maxTile)"
        maxTileLabel.position = CGPoint(x: 130, y: -12)
        row.addChild(maxTileLabel)

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
        bestValueLabel.alpha = isActive ? 0.56 : 1
        menuButton.alpha = isActive ? 0.4 : 1
        restartHudButton.alpha = isActive ? 0.42 : 1
        hintHudButton.alpha = isActive ? 0.42 : 1
        hintBadgeNode.alpha = isActive ? 0.28 : 1
    }

    // MARK: - Overlay Page Builders

    private func buildOverlayPage(for phase: ScenePhase) -> SKNode {
        let page = SKNode()

        if phase != .gameOver {
            let pageBackground = SKSpriteNode(texture: backgroundTexture(size: frame.size), size: frame.size)
            pageBackground.position = CGPoint(x: frame.midX, y: frame.midY)
            pageBackground.name = NodeName.pageBackground
            pageBackground.zPosition = -1
            page.addChild(pageBackground)
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
            buildAboutPage(into: page)
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
        let cy = frame.midY
        let snapshot = statsStore.snapshot()
        let rowSpacing: CGFloat = 62
        let listStartY = min(frame.maxY - 216, cy + 48)
        let closeButtonY = max(frame.minY + 58, cy - 198)
        let availableListHeight = max(0, listStartY - (closeButtonY + 48))
        let visibleRecordCount = min(
            snapshot.recentGames.count,
            max(4, min(6, Int(availableListHeight / rowSpacing) + 1))
        )

        let title = makeLabel(font: DesignSystem.Fonts.modalTitleFont(), color: DesignSystem.Colors.textDark)
        title.text = "历史记录"
        title.position = CGPoint(x: cx, y: min(frame.maxY - 78, cy + 184))
        page.addChild(title)

        let summary = makeStatsSummary(snapshot: snapshot)
        summary.position = CGPoint(x: cx, y: min(frame.maxY - 134, cy + 128))
        page.addChild(summary)

        let listTitle = makeLabel(font: DesignSystem.Fonts.historyRowTitleFont(), color: DesignSystem.Colors.textDark)
        listTitle.horizontalAlignmentMode = .left
        listTitle.text = "最近对局"
        listTitle.position = CGPoint(x: cx - 136, y: listStartY + 34)
        page.addChild(listTitle)

        if snapshot.recentGames.isEmpty {
            let emptyLabel = makeLabel(font: DesignSystem.Fonts.historyRowBodyFont(), color: DesignSystem.Colors.textDark)
            emptyLabel.text = "还没有历史记录，先玩几局再回来看看"
            emptyLabel.position = CGPoint(x: cx, y: listStartY - 32)
            page.addChild(emptyLabel)
        } else {
            for (index, game) in snapshot.recentGames.prefix(visibleRecordCount).enumerated() {
                let row = makeHistoryRow(game: game, rank: index + 1)
                row.position = CGPoint(x: cx, y: listStartY - CGFloat(index) * rowSpacing)
                page.addChild(row)
            }
        }

        let closeButton = makeButton(
            size: CGSize(width: 126, height: DesignSystem.Layout.modalButtonHeight),
            fillColor: DesignSystem.Colors.buttonBackground,
            text: "关闭",
            textColor: .white,
            name: NodeName.closeHistoryButton
        )
        closeButton.position = CGPoint(x: cx, y: closeButtonY)
        page.addChild(closeButton)
    }

    private func buildMenuPage(into page: SKNode) {
        let cx = frame.midX
        let topInset = max(view?.safeAreaInsets.top ?? 44, 44)
        let bottomInset = max(view?.safeAreaInsets.bottom ?? 24, 24)
        let headerY = frame.maxY - topInset - 44
        let footerCenter = CGPoint(x: cx, y: frame.minY + bottomInset + 94)
        let contentTopY = headerY - 78
        let contentBottomY = footerCenter.y + 74
        let contentCenter = CGPoint(x: cx, y: (contentTopY + contentBottomY) / 2)

        let title = makeLabel(font: DesignSystem.Fonts.modalTitleFont(), color: DesignSystem.Colors.textDark)
        title.text = currentMenuOverlayPage.title
        title.position = CGPoint(x: cx, y: headerY)
        page.addChild(title)

        let leftHint = makeLabel(font: DesignSystem.Fonts.hudSmallFont(), color: DesignSystem.Colors.textDark)
        leftHint.text = currentMenuOverlayPage == .history ? "" : "‹ \(previousMenuOverlayTitle())"
        leftHint.alpha = 0.5
        leftHint.horizontalAlignmentMode = .left
        leftHint.position = CGPoint(x: frame.minX + 28, y: headerY - 38)
        page.addChild(leftHint)

        let rightHint = makeLabel(font: DesignSystem.Fonts.hudSmallFont(), color: DesignSystem.Colors.textDark)
        rightHint.text = currentMenuOverlayPage == .about ? "" : "\(nextMenuOverlayTitle()) ›"
        rightHint.alpha = 0.5
        rightHint.horizontalAlignmentMode = .right
        rightHint.position = CGPoint(x: frame.maxX - 28, y: headerY - 38)
        page.addChild(rightHint)

        let hint = makeLabel(font: DesignSystem.Fonts.hudSmallFont(), color: DesignSystem.Colors.textDark)
        hint.text = "左右滑动切换"
        hint.alpha = 0.58
        hint.position = CGPoint(x: cx, y: headerY - 38)
        page.addChild(hint)

        let contentCard = makeSurfaceCard(size: CGSize(width: 336, height: max(260, contentTopY - contentBottomY)))
        contentCard.position = contentCenter
        contentCard.zPosition = -0.1
        page.addChild(contentCard)

        buildMenuOverlayContent(into: page, center: contentCenter)
        buildMenuOverlayFooter(into: page, center: footerCenter)
    }

    private func buildMenuOverlayContent(into page: SKNode, center: CGPoint) {
        switch currentMenuOverlayPage {
        case .history:
            buildHistoryContent(into: page, center: center)
        case .achievements:
            buildAchievementsContent(into: page, center: center)
        case .settings:
            buildSettingsContent(into: page, center: center)
        case .about:
            buildAboutPrivacyContent(into: page, center: center)
        }
    }

    private func buildSettingsContent(into page: SKNode, center: CGPoint) {
        let soundRow = makeSettingsRow(
            title: "音效",
            detail: audioManager.muted ? "已关闭" : "已开启",
            name: NodeName.soundToggleButton,
            emphasized: !audioManager.muted
        )
        soundRow.position = CGPoint(x: center.x, y: center.y + 58)
        page.addChild(soundRow)

        let privacyRow = makeSettingsRow(
            title: "隐私说明",
            detail: "本地数据与 Game Center",
            name: NodeName.privacyButton
        )
        privacyRow.position = CGPoint(x: center.x, y: center.y)
        page.addChild(privacyRow)
    }

    private func buildHistoryContent(into page: SKNode, center: CGPoint) {
        let snapshot = statsStore.snapshot()
        let rowSpacing: CGFloat = 62
        let footerTopY = frame.minY + max(view?.safeAreaInsets.bottom ?? 24, 24) + 168
        let summaryY = center.y + 104
        let listStartY = summaryY - 78
        let availableListHeight = max(0, listStartY - (footerTopY + 36))
        let visibleRecordCount = min(
            snapshot.recentGames.count,
            max(2, min(5, Int(availableListHeight / rowSpacing) + 1))
        )

        let summary = makeStatsSummary(snapshot: snapshot)
        summary.position = CGPoint(x: center.x, y: summaryY)
        page.addChild(summary)

        if snapshot.recentGames.isEmpty {
            let emptyLabel = makeLabel(font: DesignSystem.Fonts.historyRowBodyFont(), color: DesignSystem.Colors.textDark)
            emptyLabel.text = "还没有历史记录"
            emptyLabel.position = CGPoint(x: center.x, y: listStartY - 18)
            page.addChild(emptyLabel)
        } else {
            for (index, game) in snapshot.recentGames.prefix(visibleRecordCount).enumerated() {
                let row = makeHistoryRow(game: game, rank: index + 1)
                row.position = CGPoint(x: center.x, y: listStartY - CGFloat(index) * rowSpacing)
                page.addChild(row)
            }
        }
    }

    private func buildAchievementsContent(into page: SKNode, center: CGPoint) {
        let progress = gameCenterService.progressList()
        let rowSpacing: CGFloat = 39
        let topY = center.y + 132

        for (index, item) in progress.enumerated() {
            let row = makeAchievementRow(progress: item)
            row.position = CGPoint(x: center.x, y: topY - CGFloat(index) * rowSpacing)
            page.addChild(row)
        }
    }

    private func makeAchievementRow(progress: AchievementProgress) -> SKShapeNode {
        let isUnlocked = progress.unlockedAt != nil
        let row = SKShapeNode(rectOf: CGSize(width: 292, height: 36), cornerRadius: 14)
        row.fillColor = isUnlocked
            ? DesignSystem.Colors.progressFill.withAlphaComponent(0.24)
            : DesignSystem.Colors.cardBackground.withAlphaComponent(0.7)
        row.strokeColor = isUnlocked
            ? DesignSystem.Colors.progressFill.withAlphaComponent(0.5)
            : DesignSystem.Colors.cardStroke
        row.lineWidth = 1

        let badge = SKShapeNode(circleOfRadius: 9)
        badge.fillColor = isUnlocked ? DesignSystem.Colors.progressFill : DesignSystem.Colors.buttonBackground
        badge.strokeColor = UIColor.white.withAlphaComponent(0.42)
        badge.lineWidth = 1
        badge.position = CGPoint(x: -128, y: 0)
        row.addChild(badge)

        let badgeLabel = makeLabel(font: DesignSystem.Fonts.hudSmallFont(), color: isUnlocked ? .white : DesignSystem.Colors.textDark)
        badgeLabel.text = isUnlocked ? "✓" : "•"
        badgeLabel.position = CGPoint(x: 0, y: 0)
        badge.addChild(badgeLabel)

        let title = makeLabel(font: DesignSystem.Fonts.historyRowTitleFont(), color: DesignSystem.Colors.textDark)
        title.fontSize = 15
        title.horizontalAlignmentMode = .left
        title.text = progress.definition.title
        title.position = CGPoint(x: -112, y: 7)
        row.addChild(title)

        let detail = makeLabel(font: DesignSystem.Fonts.historyRowBodyFont(), color: DesignSystem.Colors.textDark)
        detail.fontSize = 11
        detail.alpha = 0.64
        detail.horizontalAlignmentMode = .left
        detail.text = progress.definition.detail
        detail.position = CGPoint(x: -112, y: -10)
        row.addChild(detail)

        let state = makeLabel(font: DesignSystem.Fonts.hudSmallFont(), color: DesignSystem.Colors.textDark)
        state.horizontalAlignmentMode = .right
        state.alpha = isUnlocked ? 0.82 : 0.54
        if let unlockedAt = progress.unlockedAt {
            state.text = achievementDateFormatter.string(from: unlockedAt)
        } else {
            state.text = "未完成"
        }
        state.position = CGPoint(x: 132, y: -1)
        row.addChild(state)

        return row
    }

    private func buildAboutPrivacyContent(into page: SKNode, center: CGPoint) {
        let lines = [
            "三衍是一款轻量数字合成游戏。",
            "1 和 2 合成 3，之后相同数字继续合成。",
            "游戏记录、最高分和音效设置保存在本机。",
            "Game Center 只提交排行榜分数和成就进度。"
        ]

        for (index, line) in lines.enumerated() {
            let label = makeLabel(font: DesignSystem.Fonts.historyRowBodyFont(), color: DesignSystem.Colors.textDark)
            label.horizontalAlignmentMode = .left
            label.text = line
            label.position = CGPoint(x: center.x - 132, y: center.y + 70 - CGFloat(index) * 38)
            page.addChild(label)
        }
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
        let cy = frame.midY

        let title = makeLabel(font: DesignSystem.Fonts.modalTitleFont(), color: DesignSystem.Colors.textDark)
        title.text = "设置"
        title.position = CGPoint(x: cx, y: cy + 140)
        page.addChild(title)

        let soundRow = makeSettingsRow(
            title: "音效",
            detail: audioManager.muted ? "已关闭" : "已开启",
            name: NodeName.soundToggleButton,
            emphasized: !audioManager.muted
        )
        soundRow.position = CGPoint(x: cx, y: cy + 70)
        page.addChild(soundRow)

        let aboutRow = makeSettingsRow(title: "关于三衍", detail: "玩法与版本", name: NodeName.aboutButton)
        aboutRow.position = CGPoint(x: cx, y: cy + 14)
        page.addChild(aboutRow)

        let privacyRow = makeSettingsRow(title: "隐私说明", detail: "本地数据与 Game Center", name: NodeName.privacyButton)
        privacyRow.position = CGPoint(x: cx, y: cy - 42)
        page.addChild(privacyRow)

        let closeButton = makeButton(
            size: CGSize(width: 126, height: DesignSystem.Layout.modalButtonHeight),
            fillColor: DesignSystem.Colors.buttonBackground,
            text: "关闭",
            textColor: .white,
            name: NodeName.closeSettingsButton
        )
        closeButton.position = CGPoint(x: cx, y: cy - 126)
        page.addChild(closeButton)
    }

    private func buildAboutPage(into page: SKNode) {
        buildInfoPage(into: page, title: "关于三衍", lines: [
            "三衍是一款轻量数字合成游戏。",
            "核心规则：1 和 2 合成 3，之后相同数字继续合成。",
            "目标是在有限空间里规划节奏，合成更高数字并刷新分数。"
        ])
    }

    private func buildPrivacyPage(into page: SKNode) {
        buildInfoPage(into: page, title: "隐私说明", lines: [
            "游戏记录、最高分和音效设置保存在本机。",
            "启用 Game Center 时，只提交排行榜分数和成就进度。",
            "应用不采集定位、通讯录或第三方广告追踪数据。"
        ])
    }

    private func buildInfoPage(into page: SKNode, title: String, lines: [String]) {
        let cx = frame.midX
        let cy = frame.midY

        let titleLabel = makeLabel(font: DesignSystem.Fonts.modalTitleFont(), color: DesignSystem.Colors.textDark)
        titleLabel.text = title
        titleLabel.position = CGPoint(x: cx, y: cy + 144)
        page.addChild(titleLabel)

        for (index, line) in lines.enumerated() {
            let label = makeLabel(font: DesignSystem.Fonts.historyRowBodyFont(), color: DesignSystem.Colors.textDark)
            label.horizontalAlignmentMode = .left
            label.text = line
            label.position = CGPoint(x: cx - 132, y: cy + 74 - CGFloat(index) * 48)
            page.addChild(label)
        }

        let backButton = makeButton(
            size: CGSize(width: 126, height: DesignSystem.Layout.modalButtonHeight),
            fillColor: DesignSystem.Colors.buttonSecondaryBackground,
            text: "返回设置",
            textColor: DesignSystem.Colors.textDark,
            name: NodeName.backToSettingsButton
        )
        backButton.position = CGPoint(x: cx - 70, y: cy - 144)
        page.addChild(backButton)

        let closeButton = makeButton(
            size: CGSize(width: 126, height: DesignSystem.Layout.modalButtonHeight),
            fillColor: DesignSystem.Colors.buttonBackground,
            text: "关闭",
            textColor: .white,
            name: NodeName.closeSettingsButton
        )
        closeButton.position = CGPoint(x: cx + 70, y: cy - 144)
        page.addChild(closeButton)
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let node = atPoint(location)

        var current: SKNode? = node
        while let candidate = current {
            switch candidate.name {
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
            case NodeName.aboutButton:
                audioManager.playButton()
                pushOverlay(phase: .about)
                return
            case NodeName.privacyButton:
                audioManager.playButton()
                if scenePhase == .menu {
                    currentMenuOverlayPage = .about
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
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }

        let scenePosition = gridNode.convert(positionForGrid(position), to: self)
        playMilestoneEffect(at: scenePosition, value: model.tile(at: position)?.value ?? 3)
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
        button.strokeColor = UIColor.white.withAlphaComponent(0.38)
        button.lineWidth = 2
        button.name = name

        let shadow = SKShapeNode(rectOf: size, cornerRadius: size.height / 2)
        shadow.fillColor = UIColor.black.withAlphaComponent(0.18)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -6)
        shadow.zPosition = -1
        shadow.name = name
        button.addChild(shadow)

        let shine = SKShapeNode(
            rectOf: CGSize(width: size.width * 0.78, height: max(4, size.height * 0.12)),
            cornerRadius: size.height * 0.06
        )
        shine.fillColor = UIColor.white.withAlphaComponent(0.22)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: -size.width * 0.02, y: size.height * 0.28)
        shine.name = name
        button.addChild(shine)

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
        button.strokeColor = UIColor.white.withAlphaComponent(0.45)
        button.lineWidth = 2
        button.name = name

        let shadow = SKShapeNode(circleOfRadius: diameter / 2)
        shadow.fillColor = UIColor.black.withAlphaComponent(0.22)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -6)
        shadow.zPosition = -1
        shadow.name = name
        button.addChild(shadow)

        let inner = SKShapeNode(circleOfRadius: diameter * 0.39)
        inner.fillColor = UIColor.white.withAlphaComponent(0.16)
        inner.strokeColor = UIColor.white.withAlphaComponent(0.2)
        inner.lineWidth = 1
        inner.name = name
        button.addChild(inner)

        let shine = SKShapeNode(ellipseOf: CGSize(width: diameter * 0.48, height: diameter * 0.16))
        shine.fillColor = UIColor.white.withAlphaComponent(0.28)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: -diameter * 0.08, y: diameter * 0.2)
        shine.name = name
        button.addChild(shine)

        let label = makeLabel(font: DesignSystem.Fonts.modalValueFont(), color: .white)
        label.fontSize = diameter * 0.48
        label.text = icon
        label.name = name
        label.position = CGPoint(x: 0, y: -1)
        button.addChild(label)

        return button
    }

    private func makeSettingsRow(
        title: String,
        detail: String,
        name: String,
        emphasized: Bool = false
    ) -> SKShapeNode {
        let row = SKShapeNode(rectOf: CGSize(width: 286, height: 44), cornerRadius: 15)
        row.fillColor = emphasized
            ? DesignSystem.Colors.progressFill.withAlphaComponent(0.22)
            : DesignSystem.Colors.cardBackground.withAlphaComponent(0.76)
        row.strokeColor = emphasized
            ? DesignSystem.Colors.progressFill.withAlphaComponent(0.52)
            : DesignSystem.Colors.cardStroke
        row.lineWidth = 1
        row.name = name

        let titleLabel = makeLabel(font: DesignSystem.Fonts.historyRowTitleFont(), color: DesignSystem.Colors.textDark)
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.text = title
        titleLabel.name = name
        titleLabel.position = CGPoint(x: -122, y: 2)
        row.addChild(titleLabel)

        let detailLabel = makeLabel(font: DesignSystem.Fonts.historyRowBodyFont(), color: DesignSystem.Colors.textDark)
        detailLabel.horizontalAlignmentMode = .right
        detailLabel.alpha = 0.72
        detailLabel.text = detail
        detailLabel.name = name
        detailLabel.position = CGPoint(x: 122, y: 1)
        row.addChild(detailLabel)

        return row
    }

    private func makeHUDCard(size: CGSize) -> SKShapeNode {
        let cornerRadius = min(20, size.height * 0.24)
        let card = SKShapeNode(rectOf: size, cornerRadius: cornerRadius)
        card.fillColor = DesignSystem.Colors.cardBackground.withAlphaComponent(0.9)
        card.strokeColor = DesignSystem.Colors.cardStroke
        card.lineWidth = 2
        card.zPosition = 29

        let shadow = SKShapeNode(rectOf: size, cornerRadius: cornerRadius)
        shadow.fillColor = UIColor.black.withAlphaComponent(0.18)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -6)
        shadow.zPosition = -1
        card.addChild(shadow)

        let shine = SKShapeNode(rectOf: CGSize(width: size.width - 12, height: max(3, size.height * 0.12)), cornerRadius: size.height * 0.06)
        shine.fillColor = UIColor.white.withAlphaComponent(0.18)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: 0, y: size.height * 0.29)
        card.addChild(shine)

        return card
    }

    private func makeSurfaceCard(size: CGSize) -> SKShapeNode {
        let card = SKShapeNode(rectOf: size, cornerRadius: 24)
        card.fillColor = DesignSystem.Colors.cardBackground.withAlphaComponent(0.88)
        card.strokeColor = DesignSystem.Colors.cardStroke
        card.lineWidth = 2

        let shadow = SKShapeNode(rectOf: size, cornerRadius: 24)
        shadow.fillColor = UIColor.black.withAlphaComponent(0.18)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -8)
        shadow.zPosition = -1
        card.addChild(shadow)

        return card
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
    case history
    case achievements
    case settings
    case about

    var title: String {
        switch self {
        case .history: return "历史记录"
        case .achievements: return "成就"
        case .settings: return "设置"
        case .about: return "关于/隐私"
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
    static let aboutButton = "aboutButton"
    static let privacyButton = "privacyButton"
    static let backToSettingsButton = "backToSettingsButton"
    static let closeSettingsButton = "closeSettingsButton"
}
