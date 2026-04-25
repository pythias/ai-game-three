import UIKit
import SpriteKit

final class GameScene: SKScene {
    // MARK: - Properties

    private let model = GameModel()
    private let spawner = Spawner()

    private var tileNodes: [GridPosition: SKNode] = [:]
    private var gridNode: SKNode!
    private var scoreLabel: SKLabelNode!

    private var isAnimating = false
    private var scenePhase: ScenePhase = .playing
    private var overlayNode: SKNode?

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = DesignSystem.Colors.background
        setupGrid()
        setupScoreLabel()
        setupTitle()
        startNewGame()
        installInput(on: view)
    }

    // MARK: - Setup

    private func setupGrid() {
        gridNode = SKNode()
        gridNode.position = CGPoint(x: 0, y: -30)
        addChild(gridNode)

        let gridSize = DesignSystem.Layout.gridSize(in: view!)
        let cellSize = DesignSystem.Layout.cellSize(gridSize: gridSize)
        let spacing = DesignSystem.Layout.gridSpacing

        for row in 0..<4 {
            for col in 0..<4 {
                let cell = SKShapeNode(rectOf: CGSize(width: cellSize, height: cellSize),
                                      cornerRadius: DesignSystem.Layout.cellCornerRadius)
                cell.fillColor = DesignSystem.Colors.emptyCell
                cell.strokeColor = .clear
                let x = CGFloat(col) * (cellSize + spacing) - gridSize / 2 + cellSize / 2
                let y = CGFloat(3 - row) * (cellSize + spacing) - gridSize / 2 + cellSize / 2
                cell.position = CGPoint(x: x, y: y)
                gridNode.addChild(cell)
            }
        }
    }

    private func setupScoreLabel() {
        scoreLabel = SKLabelNode(fontNamed: "Avenir-Heavy")
        scoreLabel.fontSize = 24
        scoreLabel.fontColor = DesignSystem.Colors.textDark
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.verticalAlignmentMode = .top
        scoreLabel.text = "0"
        let gridSize = DesignSystem.Layout.gridSize(in: view!)
        let topY = gridNode.position.y + gridSize / 2 + 20
        scoreLabel.position = CGPoint(x: gridSize / 2 - 10, y: topY - 24)
        addChild(scoreLabel)
    }

    private func setupTitle() {
        let title = SKLabelNode(fontNamed: "Avenir-Heavy")
        title.fontSize = 28
        title.fontColor = DesignSystem.Colors.textDark
        title.horizontalAlignmentMode = .left
        title.verticalAlignmentMode = .top
        title.text = "Threes!"
        let gridSize = DesignSystem.Layout.gridSize(in: view!)
        let topY = gridNode.position.y + gridSize / 2 + 20
        title.position = CGPoint(x: -gridSize / 2 + 10, y: topY - 28)
        addChild(title)
    }

    private func installInput(on view: SKView) {
        let controller = InputController(view: view)
        controller.onSwipe = { [weak self] dir in
            self?.handleSwipe(dir)
        }
    }

    // MARK: - Game Flow

    private func startNewGame() {
        model.reset()
        tileNodes.values.forEach { $0.removeFromParent() }
        tileNodes.removeAll()
        spawner.reset(for: model.board)

        // Spawn two initial tiles
        if let pos1 = model.emptyPositions.randomElement() {
            spawnTile(at: pos1, value: spawner.takePreviewTile().value)
        }
        if let pos2 = model.emptyPositions.randomElement() {
            spawnTile(at: pos2, value: spawner.takePreviewTile().value)
        }

        updateScore()
    }

    private func handleSwipe(_ swipe: SwipeDirection) {
        guard !isAnimating else { return }
        guard scenePhase == .playing else { return }

        let dir = directionForSwipe(swipe)
        let result = model.move(dir)

        guard result.didMove else {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
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
        // Animate tile movements
        for movement in result.movements {
            if let node = tileNodes[movement.from] {
                let toPos = positionForGrid(movement.to)
                let move = SKAction.move(to: toPos, duration: DesignSystem.Animation.moveDuration)
                move.timingMode = .easeOut
                node.run(move)
            }
        }

        run(SKAction.wait(forDuration: DesignSystem.Animation.moveDuration)) { [weak self] in
            self?.finishMove(result: result)
        }
    }

    private func finishMove(result: MoveResult) {
        // Rebuild tile nodes from model state (handles merges correctly)
        rebuildTileNodes()

        // Spawn new tile at spawnCandidates position
        if let spawnPos = result.spawnCandidates.randomElement() {
            spawnTile(at: spawnPos, value: spawner.takePreviewTile().value)
        }
        spawner.refreshPreview(for: model.board)

        updateScore()
        isAnimating = false

        if model.isGameOver {
            showGameOver()
        }
    }

    // MARK: - Tile Nodes

    private func positionForGrid(_ pos: GridPosition) -> CGPoint {
        let gridSize = DesignSystem.Layout.gridSize(in: view!)
        let cellSize = DesignSystem.Layout.cellSize(gridSize: gridSize)
        let spacing = DesignSystem.Layout.gridSpacing
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

        let scaleUp = SKAction.scale(to: 1.0, duration: DesignSystem.Animation.spawnDuration)
        scaleUp.timingMode = .easeOut
        node.run(scaleUp)
    }

    private func makeTileNode(value: Int) -> SKNode {
        let gridSize = DesignSystem.Layout.gridSize(in: view!)
        let cellSize = DesignSystem.Layout.cellSize(gridSize: gridSize)

        let container = SKNode()

        // Background
        let bg = SKShapeNode(rectOf: CGSize(width: cellSize, height: cellSize),
                             cornerRadius: DesignSystem.Layout.tileCornerRadius)
        bg.fillColor = DesignSystem.Colors.tileBackground(for: value)
        bg.strokeColor = .clear
        bg.name = "bg"
        container.addChild(bg)

        // Label
        let label = SKLabelNode(text: "\(value)")
        label.fontName = "Avenir-Heavy"
        label.fontSize = DesignSystem.Fonts.tileFont(for: value).pointSize
        label.fontColor = DesignSystem.Colors.tileText(for: value)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.name = "label"
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

    // MARK: - Score

    private func updateScore() {
        scoreLabel.text = "\(model.score)"
    }

    // MARK: - Game Over

    private func showGameOver() {
        scenePhase = .gameOver

        let overlay = SKShapeNode(rectOf: CGSize(width: 300, height: 180), cornerRadius: 12)
        overlay.fillColor = UIColor.black.withAlphaComponent(0.5)
        overlay.strokeColor = .clear
        overlay.name = "overlay"
        overlay.position = CGPoint(x: 0, y: 0)
        addChild(overlay)

        // Title
        let titleLabel = SKLabelNode(text: "游戏结束")
        titleLabel.fontSize = 36
        titleLabel.fontColor = .white
        titleLabel.fontName = "Avenir-Heavy"
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 0, y: 35)
        overlay.addChild(titleLabel)

        // Button bg
        let buttonBg = SKShapeNode(rectOf: CGSize(width: 140, height: 44), cornerRadius: 8)
        buttonBg.fillColor = .white
        buttonBg.strokeColor = .clear
        buttonBg.name = "restartBtn"
        buttonBg.position = CGPoint(x: 0, y: -25)
        overlay.addChild(buttonBg)

        // Button label
        let buttonLabel = SKLabelNode(text: "再来一局")
        buttonLabel.fontSize = 20
        buttonLabel.fontColor = DesignSystem.Colors.textDark
        buttonLabel.fontName = "Avenir-Heavy"
        buttonLabel.verticalAlignmentMode = .center
        buttonLabel.horizontalAlignmentMode = .center
        buttonLabel.name = "restartLabel"
        buttonLabel.position = CGPoint(x: 0, y: -25)
        overlay.addChild(buttonLabel)

        overlayNode = overlay
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard scenePhase == .gameOver, let touch = touches.first else { return }
        let location = touch.location(in: self)
        let node = atPoint(location)

        // Check if tapped on restart button or its background
        var current: SKNode? = node
        while let n = current {
            if n.name == "restartBtn" || n.name == "restartLabel" {
                hideOverlay()
                startNewGame()
                scenePhase = .playing
                return
            }
            current = n.parent
        }
    }

    private func hideOverlay() {
        overlayNode?.removeFromParent()
        overlayNode = nil
    }
}

// MARK: - ScenePhase

private enum ScenePhase {
    case playing
    case gameOver
}
