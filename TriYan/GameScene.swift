import UIKit
import SpriteKit

final class GameScene: SKScene {
    // MARK: - Properties

    private let model = GameModel()
    private let spawner = Spawner()
    private let statsStore = StatsStore.shared
    private let gameCenterService = GameCenterService.shared

    private var tileNodes: [GridPosition: SKNode] = [:]
    private var gridNode: SKNode!

    private var titleLabel: SKLabelNode!
    private var nextTitleLabel: SKLabelNode!
    private var nextValueLabel: SKLabelNode!
    private var scoreTitleLabel: SKLabelNode!
    private var scoreValueLabel: SKLabelNode!
    private var historyButton: SKShapeNode!

    private var inputController: InputController?
    private var overlayNode: SKNode?

    private var isAnimating = false
    private var scenePhase: ScenePhase = .playing
    private var historyReturnPhase: ScenePhase = .playing
    private var didRecordCurrentGame = false

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
            startNewGame()
        }
        layoutScene()
        installInput(on: view)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard gridNode != nil else { return }
        layoutScene()
        rebuildTileNodes()
        rebuildOverlayForCurrentPhase()
    }

    // MARK: - Setup

    private func setupGrid() {
        gridNode = SKNode()
        addChild(gridNode)
    }

    private func setupHUD() {
        titleLabel = makeLabel(font: DesignSystem.Fonts.titleFont(), color: DesignSystem.Colors.textDark)
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .top
        titleLabel.text = "三衍"
        addChild(titleLabel)

        nextTitleLabel = makeLabel(font: DesignSystem.Fonts.hudLabelFont(), color: DesignSystem.Colors.textDark)
        nextTitleLabel.text = "下一个"
        addChild(nextTitleLabel)

        nextValueLabel = makeLabel(font: DesignSystem.Fonts.hudValueFont(), color: DesignSystem.Colors.textDark)
        nextValueLabel.text = "1"
        addChild(nextValueLabel)

        scoreTitleLabel = makeLabel(font: DesignSystem.Fonts.hudLabelFont(), color: DesignSystem.Colors.textDark)
        scoreTitleLabel.horizontalAlignmentMode = .right
        scoreTitleLabel.text = "分数"
        addChild(scoreTitleLabel)

        scoreValueLabel = makeLabel(font: DesignSystem.Fonts.hudValueFont(), color: DesignSystem.Colors.textDark)
        scoreValueLabel.horizontalAlignmentMode = .right
        scoreValueLabel.text = "0"
        addChild(scoreValueLabel)

        historyButton = makeButton(
            size: CGSize(width: 60, height: DesignSystem.Layout.hudButtonSize.height),
            fillColor: DesignSystem.Colors.buttonSecondaryBackground,
            text: "记录",
            textColor: DesignSystem.Colors.textDark,
            name: NodeName.historyHudButton
        )
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

        gridNode.position = CGPoint(x: frame.midX, y: boardCenterY)

        titleLabel.position = CGPoint(x: frame.minX + leftInset + padding, y: headerY)
        historyButton.position = CGPoint(
            x: frame.minX + leftInset + padding + DesignSystem.Layout.hudTitleWidth + 34,
            y: headerY - 18
        )

        nextTitleLabel.position = CGPoint(x: frame.midX, y: headerY - 2)
        nextValueLabel.position = CGPoint(x: frame.midX, y: headerY - 28)

        scoreTitleLabel.position = CGPoint(x: frame.maxX - rightInset - padding, y: headerY - 2)
        scoreValueLabel.position = CGPoint(x: frame.maxX - rightInset - padding, y: headerY - 28)

        layoutGridBackground(gridSize: gridSize)
    }

    private func layoutGridBackground(gridSize: CGFloat) {
        gridNode.children.filter { $0.name == NodeName.cell }.forEach { $0.removeFromParent() }

        let cellSize = DesignSystem.Layout.cellSize(gridSize: gridSize)
        let spacing = DesignSystem.Layout.gridSpacing

        for row in 0..<4 {
            for col in 0..<4 {
                let cell = SKShapeNode(
                    rectOf: CGSize(width: cellSize, height: cellSize),
                    cornerRadius: DesignSystem.Layout.cellCornerRadius
                )
                cell.fillColor = DesignSystem.Colors.emptyCell
                cell.strokeColor = .clear
                cell.name = NodeName.cell
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

        model.reset()
        tileNodes.values.forEach { $0.removeFromParent() }
        tileNodes.removeAll()
        spawner.reset(for: model.board)

        if let pos1 = model.emptyPositions.randomElement() {
            let firstTile = spawner.takePreviewTile()
            model.place(firstTile, at: pos1)
            spawnTile(at: pos1, value: firstTile.value)
            spawner.refreshPreview(for: model.board)
        }

        if let pos2 = model.emptyPositions.randomElement() {
            let secondTile = spawner.takePreviewTile()
            model.place(secondTile, at: pos2)
            spawnTile(at: pos2, value: secondTile.value)
            spawner.refreshPreview(for: model.board)
        }

        updateHUD()
    }

    private func handleSwipe(_ swipe: SwipeDirection) {
        guard !isAnimating, scenePhase == .playing else { return }

        let result = model.move(directionForSwipe(swipe))
        guard result.didMove else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }

        isAnimating = true
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
        rebuildTileNodes()

        if let spawnPos = result.spawnCandidates.randomElement() {
            let spawnedTile = spawner.takePreviewTile()
            model.place(spawnedTile, at: spawnPos)
            spawnTile(at: spawnPos, value: spawnedTile.value)
        }
        spawner.refreshPreview(for: model.board)

        updateHUD()
        isAnimating = false

        if model.isGameOver {
            showGameOver()
        }
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

    private func makeTileNode(value: Int) -> SKNode {
        guard let view else { return SKNode() }
        let gridSize = DesignSystem.Layout.gridSize(in: view)
        let cellSize = DesignSystem.Layout.cellSize(gridSize: gridSize)

        let container = SKNode()

        let background = SKShapeNode(
            rectOf: CGSize(width: cellSize, height: cellSize),
            cornerRadius: DesignSystem.Layout.tileCornerRadius
        )
        background.fillColor = DesignSystem.Colors.tileBackground(for: value)
        background.strokeColor = .clear
        container.addChild(background)

        let label = SKLabelNode(text: "\(value)")
        label.fontName = DesignSystem.Fonts.tileFont(for: value).fontName
        label.fontSize = DesignSystem.Fonts.tileFont(for: value).pointSize
        label.fontColor = DesignSystem.Colors.tileText(for: value)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        container.addChild(label)

        return container
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
        nextValueLabel.text = "\(spawner.previewTile.value)"
    }

    private func formatScore(_ score: Int) -> String {
        scoreFormatter.string(from: NSNumber(value: score)) ?? "\(score)"
    }

    // MARK: - Overlays

    private func showGameOver() {
        recordCurrentGameIfNeeded()
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

    private func recordCurrentGameIfNeeded() {
        guard !didRecordCurrentGame else { return }

        let previousBest = statsStore.bestScore()
        statsStore.recordGame(
            resultScore: model.score,
            histogram: model.tileHistogramFromThree()
        )

        if model.score >= previousBest {
            gameCenterService.submit(score: model.score)
        }

        didRecordCurrentGame = true
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
                showHistory(from: scenePhase)
                return
            case NodeName.gameOverHistoryButton:
                showHistory(from: .gameOver)
                return
            case NodeName.restartButton:
                startNewGame()
                return
            case NodeName.closeHistoryButton:
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

        let label = makeLabel(font: DesignSystem.Fonts.buttonFont(), color: textColor)
        label.text = text
        label.name = name
        label.position = CGPoint(x: 0, y: -1)
        button.addChild(label)

        return button
    }
}

private enum ScenePhase {
    case playing
    case gameOver
    case history
}

private enum NodeName {
    static let cell = "cell"
    static let scrim = "scrim"
    static let historyHudButton = "historyHudButton"
    static let gameOverHistoryButton = "gameOverHistoryButton"
    static let restartButton = "restartButton"
    static let closeHistoryButton = "closeHistoryButton"
}
