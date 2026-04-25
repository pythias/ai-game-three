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

    private var titleLabel: SKLabelNode!
    private var subtitleLabel: SKLabelNode!
    private var nextCardNode: SKShapeNode!
    private var nextTitleLabel: SKLabelNode!
    private var nextPreviewNode: SKNode!
    private var scoreCardNode: SKShapeNode!
    private var scoreTitleLabel: SKLabelNode!
    private var scoreValueLabel: SKLabelNode!
    private var bestValueLabel: SKLabelNode!
    private var historyButton: SKShapeNode!

    private var inputController: InputController?
    private var overlayNode: SKNode?
    private var achievementToastNode: SKNode?

    private var isAnimating = false
    private var scenePhase: ScenePhase = .playing
    private var historyReturnPhase: ScenePhase = .playing
    private var didRecordCurrentGame = false
    private var mergeStreak = 0
    private var pendingSwipe: SwipeDirection?

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

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = DesignSystem.Colors.background
        if gridNode == nil {
            setupGrid()
            setupHUD()
            layoutScene()
            prewarmTileTextures()
            startNewGame()
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
        rebuildOverlayForCurrentPhase()
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
        titleLabel = makeLabel(font: DesignSystem.Fonts.titleFont(), color: DesignSystem.Colors.textDark)
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .top
        titleLabel.text = "三衍"
        titleLabel.zPosition = 30
        addChild(titleLabel)

        subtitleLabel = makeLabel(font: DesignSystem.Fonts.hudSmallFont(), color: DesignSystem.Colors.textDark)
        subtitleLabel.horizontalAlignmentMode = .left
        subtitleLabel.alpha = 0.72
        subtitleLabel.text = "1 + 2 = 3"
        subtitleLabel.zPosition = 30
        addChild(subtitleLabel)

        nextCardNode = makeHUDCard(size: DesignSystem.Layout.nextCardSize)
        addChild(nextCardNode)

        nextTitleLabel = makeLabel(font: DesignSystem.Fonts.hudLabelFont(), color: DesignSystem.Colors.textDark)
        nextTitleLabel.text = "下一个"
        nextTitleLabel.zPosition = 31
        addChild(nextTitleLabel)

        nextPreviewNode = SKNode()
        nextPreviewNode.zPosition = 31
        addChild(nextPreviewNode)

        scoreCardNode = makeHUDCard(size: DesignSystem.Layout.scoreCardSize)
        addChild(scoreCardNode)

        scoreTitleLabel = makeLabel(font: DesignSystem.Fonts.hudLabelFont(), color: DesignSystem.Colors.textDark)
        scoreTitleLabel.horizontalAlignmentMode = .right
        scoreTitleLabel.text = "分数"
        scoreTitleLabel.zPosition = 31
        addChild(scoreTitleLabel)

        scoreValueLabel = makeLabel(font: DesignSystem.Fonts.hudValueFont(), color: DesignSystem.Colors.textDark)
        scoreValueLabel.horizontalAlignmentMode = .right
        scoreValueLabel.text = "0"
        scoreValueLabel.zPosition = 31
        addChild(scoreValueLabel)

        bestValueLabel = makeLabel(font: DesignSystem.Fonts.hudSmallFont(), color: DesignSystem.Colors.textDark)
        bestValueLabel.horizontalAlignmentMode = .right
        bestValueLabel.text = "BEST 0"
        bestValueLabel.alpha = 0.74
        bestValueLabel.zPosition = 31
        addChild(bestValueLabel)

        historyButton = makeButton(
            size: CGSize(width: 72, height: DesignSystem.Layout.hudButtonSize.height),
            fillColor: DesignSystem.Colors.buttonSecondaryBackground,
            text: "记录",
            textColor: DesignSystem.Colors.textDark,
            name: NodeName.historyHudButton
        )
        historyButton.zPosition = 30
        addChild(historyButton)
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

        let padding = DesignSystem.Layout.screenPadding
        let safeInsets = view.safeAreaInsets
        let topInset = max(safeInsets.top, 44)
        let leftInset = max(safeInsets.left, 0)
        let rightInset = max(safeInsets.right, 0)
        let safeTop = frame.maxY - topInset
        let headerY = safeTop - 24
        let gridSize = DesignSystem.Layout.gridSize(in: view)
        let boardCenterY = frame.midY - 20

        layoutBackground(size: frame.size)
        gridNode.position = CGPoint(x: frame.midX, y: boardCenterY)

        titleLabel.position = CGPoint(x: frame.minX + leftInset + padding, y: headerY)
        subtitleLabel.position = CGPoint(x: titleLabel.position.x + 1, y: headerY - 32)
        historyButton.position = CGPoint(
            x: frame.minX + leftInset + padding + 38,
            y: headerY - 58
        )

        nextCardNode.position = CGPoint(x: frame.midX - 4, y: headerY - 38)
        nextTitleLabel.position = CGPoint(x: nextCardNode.position.x, y: headerY - 16)
        nextPreviewNode.position = CGPoint(x: nextCardNode.position.x, y: headerY - 52)

        scoreCardNode.position = CGPoint(x: frame.maxX - rightInset - padding - DesignSystem.Layout.scoreCardSize.width / 2, y: headerY - 34)
        scoreTitleLabel.position = CGPoint(x: frame.maxX - rightInset - padding - 14, y: headerY - 12)
        scoreValueLabel.position = CGPoint(x: frame.maxX - rightInset - padding - 14, y: headerY - 36)
        bestValueLabel.position = CGPoint(x: frame.maxX - rightInset - padding - 14, y: headerY - 58)

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
        let spacing = DesignSystem.Layout.gridSpacing
        let panelSize = CGSize(width: gridSize + 18, height: gridSize + 18)
        let panelShadow = SKShapeNode(rectOf: panelSize, cornerRadius: 24)
        panelShadow.fillColor = UIColor.black.withAlphaComponent(0.1)
        panelShadow.strokeColor = .clear
        panelShadow.name = NodeName.boardPanel
        panelShadow.position = CGPoint(x: 0, y: -8)
        panelShadow.zPosition = -3
        gridNode.addChild(panelShadow)

        let panel = SKShapeNode(rectOf: panelSize, cornerRadius: 24)
        panel.fillColor = DesignSystem.Colors.boardBackground
        panel.strokeColor = DesignSystem.Colors.cardStroke
        panel.lineWidth = 1
        panel.name = NodeName.boardPanel
        panel.zPosition = -2
        gridNode.addChild(panel)

        for row in 0..<4 {
            for col in 0..<4 {
                let cell = SKShapeNode(
                    rectOf: CGSize(width: cellSize, height: cellSize),
                    cornerRadius: DesignSystem.Layout.cellCornerRadius
                )
                cell.fillColor = DesignSystem.Colors.emptyCell
                cell.strokeColor = UIColor.white.withAlphaComponent(0.18)
                cell.lineWidth = 1
                cell.name = NodeName.cell
                cell.alpha = 0.76
                cell.zPosition = -1
                cell.position = pointForGridPosition(
                    GridPosition(row: row, col: col),
                    gridSize: gridSize,
                    cellSize: cellSize,
                    spacing: spacing
                )
                gridNode.addChild(cell)
            }
        }
    }

    // MARK: - Game Flow

    private func startNewGame() {
        hideOverlay()
        scenePhase = .playing
        historyReturnPhase = .playing
        didRecordCurrentGame = false
        isAnimating = false
        mergeStreak = 0
        pendingSwipe = nil
        achievementToastNode?.removeFromParent()
        achievementToastNode = nil

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
    }

    private func handleSwipe(_ swipe: SwipeDirection) {
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
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
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
            cellSize: cellSize,
            spacing: DesignSystem.Layout.gridSpacing
        )
    }

    private func pointForGridPosition(
        _ pos: GridPosition,
        gridSize: CGFloat,
        cellSize: CGFloat,
        spacing: CGFloat
    ) -> CGPoint {
        let x = CGFloat(pos.col) * (cellSize + spacing) - gridSize / 2 + cellSize / 2
        let y = CGFloat(3 - pos.row) * (cellSize + spacing) - gridSize / 2 + cellSize / 2
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
        let node = SKSpriteNode(texture: texture, size: CGSize(width: size, height: size))
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

    private func tileTexture(value: Int, size: CGFloat) -> SKTexture {
        let key = TileTextureKey(value: value, size: Int(size.rounded()))
        if let cached = tileTextureCache[key] {
            return cached
        }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            let cgContext = context.cgContext
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            let path = UIBezierPath(
                roundedRect: rect,
                cornerRadius: DesignSystem.Layout.tileCornerRadius
            )
            let baseColor = DesignSystem.Colors.tileBackground(for: value)
            let highlightColor = DesignSystem.Colors.tileHighlight(for: value)

            cgContext.saveGState()
            path.addClip()
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [highlightColor.cgColor, baseColor.cgColor] as CFArray,
                locations: [0, 1]
            ) {
                cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size, y: size),
                    options: []
                )
            } else {
                baseColor.setFill()
                path.fill()
            }
            cgContext.restoreGState()

            UIColor.black.withAlphaComponent(value <= 3 ? 0.08 : 0.14).setFill()
            UIBezierPath(
                roundedRect: CGRect(x: 0, y: size * 0.72, width: size, height: size * 0.28),
                cornerRadius: DesignSystem.Layout.tileCornerRadius
            ).fill()

            UIColor.white.withAlphaComponent(value <= 3 ? 0.42 : 0.26).setFill()
            UIBezierPath(
                roundedRect: CGRect(x: size * 0.12, y: size * 0.1, width: size * 0.76, height: size * 0.18),
                cornerRadius: size * 0.09
            ).fill()

            UIColor.white.withAlphaComponent(0.28).setStroke()
            path.lineWidth = 1
            path.stroke()

            let tileFont = DesignSystem.Fonts.tileFont(for: value)
            let font = tileFont.withSize(min(tileFont.pointSize, size * 0.58))
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let text = "\(value)" as NSString
            let shadow = NSShadow()
            shadow.shadowBlurRadius = value <= 3 ? 0 : 2
            shadow.shadowOffset = CGSize(width: 0, height: 1)
            shadow.shadowColor = UIColor.black.withAlphaComponent(value <= 3 ? 0 : 0.2)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: DesignSystem.Colors.tileText(for: value),
                .paragraphStyle: paragraph,
                .shadow: shadow
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: 0,
                y: (size - textSize.height) / 2 - size * 0.025,
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

        for row in 0..<4 {
            for col in 0..<4 {
                let pos = GridPosition(row: row, col: col)
                if let tile = model.tile(at: pos) {
                    let node = makeTileNode(value: tile.value)
                    node.position = positionForGrid(pos)
                    gridNode.addChild(node)
                    tileNodes[pos] = node
                }
            }
        }
    }

    // MARK: - HUD

    private func updateHUD() {
        scoreValueLabel.text = formatScore(model.score)
        bestValueLabel.text = "BEST \(formatScore(max(model.score, statsStore.bestScore())))"
        updatePreviewTile(animated: true)
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

        let value = spawner.previewTile.value
        if previewTileValue == value, let tile = previewTileNode {
            guard animated else { return }

            tile.removeAction(forKey: "previewPop")
            tile.setScale(0.86)
            let pop = SKAction.scale(to: 1, duration: DesignSystem.Animation.previewDuration)
            pop.timingMode = .easeOut
            tile.run(pop, withKey: "previewPop")
            return
        }

        let tile = makeTileNode(
            value: value,
            size: DesignSystem.Layout.previewTileSize.width
        )
        tile.setScale(animated ? 0.72 : 1)
        nextPreviewNode.removeAllChildren()
        nextPreviewNode.addChild(tile)
        previewTileNode = tile
        previewTileValue = value

        guard animated else { return }

        let pop = SKAction.scale(to: 1, duration: DesignSystem.Animation.previewDuration)
        pop.timingMode = .easeOut
        tile.run(pop)
    }

    private func formatScore(_ score: Int) -> String {
        scoreFormatter.string(from: NSNumber(value: score)) ?? "\(score)"
    }

    // MARK: - Overlays

    private func showGameOver() {
        let wasGameOver = scenePhase == .gameOver
        let achievementUnlocks = recordCurrentGameIfNeeded()
        if !wasGameOver {
            audioManager.playGameOver()
        }
        scenePhase = .gameOver
        hideOverlay()

        let overlay = makeOverlayRoot()
        let card = makeCard(size: DesignSystem.Layout.modalCardSize)
        overlay.addChild(card)

        let snapshot = statsStore.snapshot()

        let title = makeLabel(font: DesignSystem.Fonts.modalTitleFont(), color: DesignSystem.Colors.textDark)
        title.text = "游戏结束"
        title.position = CGPoint(x: 0, y: 90)
        card.addChild(title)

        let scoreTitle = makeLabel(font: DesignSystem.Fonts.hudLabelFont(), color: DesignSystem.Colors.textDark)
        scoreTitle.text = "本局分数"
        scoreTitle.position = CGPoint(x: -70, y: 34)
        card.addChild(scoreTitle)

        let scoreValue = makeLabel(font: DesignSystem.Fonts.modalValueFont(), color: DesignSystem.Colors.textDark)
        scoreValue.text = formatScore(model.score)
        scoreValue.position = CGPoint(x: 72, y: 32)
        card.addChild(scoreValue)

        let bestTitle = makeLabel(font: DesignSystem.Fonts.hudLabelFont(), color: DesignSystem.Colors.textDark)
        bestTitle.text = "历史最高"
        bestTitle.position = CGPoint(x: -70, y: -8)
        card.addChild(bestTitle)

        let bestValue = makeLabel(font: DesignSystem.Fonts.modalValueFont(), color: DesignSystem.Colors.textDark)
        bestValue.text = formatScore(snapshot.bestScore)
        bestValue.position = CGPoint(x: 72, y: -10)
        card.addChild(bestValue)

        let historyButton = makeButton(
            size: CGSize(width: 126, height: DesignSystem.Layout.modalButtonHeight),
            fillColor: DesignSystem.Colors.buttonSecondaryBackground,
            text: "历史记录",
            textColor: DesignSystem.Colors.textDark,
            name: NodeName.gameOverHistoryButton
        )
        historyButton.position = CGPoint(x: -70, y: -86)
        card.addChild(historyButton)

        let restartButton = makeButton(
            size: CGSize(width: 126, height: DesignSystem.Layout.modalButtonHeight),
            fillColor: DesignSystem.Colors.buttonBackground,
            text: "再来一局",
            textColor: .white,
            name: NodeName.restartButton
        )
        restartButton.position = CGPoint(x: 70, y: -86)
        card.addChild(restartButton)

        overlayNode = overlay
        addChild(overlay)
        showAchievementToasts(achievementUnlocks)
    }

    private func showHistory(from phase: ScenePhase) {
        historyReturnPhase = phase
        scenePhase = .history
        hideOverlay()

        let overlay = makeOverlayRoot()
        let card = makeCard(size: DesignSystem.Layout.historyCardSize)
        overlay.addChild(card)

        let snapshot = statsStore.snapshot()

        let title = makeLabel(font: DesignSystem.Fonts.modalTitleFont(), color: DesignSystem.Colors.textDark)
        title.text = "历史记录"
        title.position = CGPoint(x: 0, y: 152)
        card.addChild(title)

        let bestLabel = makeLabel(font: DesignSystem.Fonts.hudLabelFont(), color: DesignSystem.Colors.textDark)
        bestLabel.text = "最高分  \(formatScore(snapshot.bestScore))"
        bestLabel.position = CGPoint(x: 0, y: 118)
        card.addChild(bestLabel)

        let listTitle = makeLabel(font: DesignSystem.Fonts.historyRowTitleFont(), color: DesignSystem.Colors.textDark)
        listTitle.horizontalAlignmentMode = .left
        listTitle.text = "最近对局"
        listTitle.position = CGPoint(x: -136, y: 80)
        card.addChild(listTitle)

        if snapshot.recentGames.isEmpty {
            let emptyLabel = makeLabel(font: DesignSystem.Fonts.historyRowBodyFont(), color: DesignSystem.Colors.textDark)
            emptyLabel.text = "还没有历史记录"
            emptyLabel.position = CGPoint(x: 0, y: 10)
            card.addChild(emptyLabel)
        } else {
            for (index, game) in snapshot.recentGames.prefix(6).enumerated() {
                let row = makeHistoryRow(game: game)
                row.position = CGPoint(x: 0, y: 42 - CGFloat(index) * 46)
                card.addChild(row)
            }
        }

        let closeButton = makeButton(
            size: CGSize(width: 126, height: DesignSystem.Layout.modalButtonHeight),
            fillColor: DesignSystem.Colors.buttonBackground,
            text: "关闭",
            textColor: .white,
            name: NodeName.closeHistoryButton
        )
        closeButton.position = CGPoint(x: 0, y: -148)
        card.addChild(closeButton)

        overlayNode = overlay
        addChild(overlay)
    }

    private func makeHistoryRow(game: GameRecord) -> SKNode {
        let row = SKNode()

        let background = SKShapeNode(
            rectOf: CGSize(width: 284, height: 38),
            cornerRadius: 12
        )
        background.fillColor = UIColor.white.withAlphaComponent(0.72)
        background.strokeColor = .clear
        row.addChild(background)

        let timeLabel = makeLabel(font: DesignSystem.Fonts.historyRowBodyFont(), color: DesignSystem.Colors.textDark)
        timeLabel.horizontalAlignmentMode = .left
        timeLabel.text = historyDateFormatter.string(from: game.playedAt)
        timeLabel.position = CGPoint(x: -128, y: -1)
        row.addChild(timeLabel)

        let scoreLabel = makeLabel(font: DesignSystem.Fonts.historyRowBodyFont(), color: DesignSystem.Colors.textDark)
        scoreLabel.text = formatScore(game.score)
        scoreLabel.position = CGPoint(x: 24, y: -1)
        row.addChild(scoreLabel)

        let maxTileLabel = makeLabel(font: DesignSystem.Fonts.historyRowBodyFont(), color: DesignSystem.Colors.textDark)
        maxTileLabel.horizontalAlignmentMode = .right
        maxTileLabel.text = "最高 \(game.maxTile)"
        maxTileLabel.position = CGPoint(x: 126, y: -1)
        row.addChild(maxTileLabel)

        return row
    }

    private func recordCurrentGameIfNeeded() -> [AchievementUnlock] {
        guard !didRecordCurrentGame else { return [] }

        let previousBest = statsStore.bestScore()
        statsStore.recordGame(
            resultScore: model.score,
            histogram: model.tileHistogramFromThree()
        )
        let snapshot = statsStore.snapshot()

        if model.score >= previousBest {
            gameCenterService.submit(score: model.score)
        }

        didRecordCurrentGame = true
        return gameCenterService.reportAchievements(
            score: model.score,
            maxTile: model.maxTileValue,
            gamesPlayed: snapshot.gamesPlayed
        )
    }

    private func closeHistoryOverlay() {
        hideOverlay()
        switch historyReturnPhase {
        case .playing:
            scenePhase = .playing
        case .gameOver:
            showGameOver()
        case .history:
            scenePhase = .playing
        }
    }

    private func rebuildOverlayForCurrentPhase() {
        switch scenePhase {
        case .playing:
            hideOverlay()
        case .gameOver:
            showGameOver()
        case .history:
            showHistory(from: historyReturnPhase)
        }
    }

    private func makeOverlayRoot() -> SKNode {
        let root = SKNode()
        root.zPosition = 100

        let scrim = SKSpriteNode(color: DesignSystem.Colors.overlayScrim, size: frame.size)
        scrim.position = CGPoint(x: frame.midX, y: frame.midY)
        scrim.name = NodeName.scrim
        root.addChild(scrim)

        return root
    }

    private func makeCard(size: CGSize) -> SKShapeNode {
        let card = SKShapeNode(rectOf: size, cornerRadius: DesignSystem.Layout.modalCornerRadius)
        card.fillColor = DesignSystem.Colors.cardBackground
        card.strokeColor = UIColor.white.withAlphaComponent(0.6)
        card.lineWidth = 1
        card.position = CGPoint(x: frame.midX, y: frame.midY)
        return card
    }

    private func hideOverlay() {
        overlayNode?.removeFromParent()
        overlayNode = nil
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let node = atPoint(location)

        var current: SKNode? = node
        while let candidate = current {
            switch candidate.name {
            case NodeName.historyHudButton:
                audioManager.playButton()
                showHistory(from: scenePhase)
                return
            case NodeName.gameOverHistoryButton:
                audioManager.playButton()
                showHistory(from: .gameOver)
                return
            case NodeName.restartButton:
                audioManager.playButton()
                startNewGame()
                return
            case NodeName.closeHistoryButton:
                audioManager.playButton()
                closeHistoryOverlay()
                return
            default:
                current = candidate.parent
            }
        }
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
        button.strokeColor = .clear
        button.name = name

        let shadow = SKShapeNode(rectOf: size, cornerRadius: size.height / 2)
        shadow.fillColor = UIColor.black.withAlphaComponent(0.08)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -3)
        shadow.zPosition = -1
        shadow.name = name
        button.addChild(shadow)

        let label = makeLabel(font: DesignSystem.Fonts.buttonFont(), color: textColor)
        label.text = text
        label.name = name
        label.position = CGPoint(x: 0, y: -1)
        button.addChild(label)

        return button
    }

    private func makeHUDCard(size: CGSize) -> SKShapeNode {
        let card = SKShapeNode(rectOf: size, cornerRadius: 20)
        card.fillColor = DesignSystem.Colors.cardBackground.withAlphaComponent(0.82)
        card.strokeColor = DesignSystem.Colors.cardStroke
        card.lineWidth = 1
        card.zPosition = 29

        let shadow = SKShapeNode(rectOf: size, cornerRadius: 20)
        shadow.fillColor = UIColor.black.withAlphaComponent(0.08)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -5)
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
    static let historyHudButton = "historyHudButton"
    static let gameOverHistoryButton = "gameOverHistoryButton"
    static let restartButton = "restartButton"
    static let closeHistoryButton = "closeHistoryButton"
}
