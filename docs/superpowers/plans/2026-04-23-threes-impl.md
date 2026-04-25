# Threes! 重构实现计划

**目标：** 用最简单的滑动操作 + Threes! 玩法重建 TriYan
**架构：** SpriteKit (GameScene) + UIKit (GameViewController)，GameModel/Tile/Spawner 保持不变

---

## 文件结构

- **保留不变**：`GameModel.swift`、`Tile.swift`、`Spawner.swift`、`AppDelegate.swift`
- **重写**：`GameScene.swift`、`InputController.swift`、`DesignSystem.swift`
- **简化**：`GameViewController.swift`（最小改动）
- **删除**：`EffectsManager.swift`、`AchievementManager.swift`、`GameCenterService.swift`、`ThemeManager.swift`

---

## Task 1: DesignSystem.swift —— 配色常量

**文件：** 重写 `TriYan/DesignSystem.swift`

- [ ] **Step 1: 重写文件**

```swift
import UIKit
import SpriteKit

enum DesignSystem {
    // MARK: - Colors
    enum Colors {
        static let emptyCell = UIColor(hex: "#CDC1B4")
        static let background = UIColor(hex: "#FAF8EF")
        static let textDark = UIColor(hex: "#776E65")
        static let textLight = UIColor.white

        static func tileBackground(for value: Int) -> UIColor {
            switch value {
            case 1: return UIColor(hex: "#FFFFFF")
            case 2: return UIColor(hex: "#FF3344")
            case 3: return UIColor(hex: "#FF99AA")
            case 6: return UIColor(hex: "#FF7744")
            case 12: return UIColor(hex: "#FFCC33")
            case 24: return UIColor(hex: "#DDAA22")
            case 48: return UIColor(hex: "#BBBB33")
            case 96: return UIColor(hex: "#88CC44")
            case 192: return UIColor(hex: "#44BB66")
            case 384: return UIColor(hex: "#33AA88")
            default:
                if value >= 768 { return UIColor(hex: "#33AACC") }
                return UIColor(hex: "#CDC1B4")
            }
        }

        static func tileText(for value: Int) -> UIColor {
            switch value {
            case 1: return UIColor(hex: "#A39C90")
            case 2, 3, 6, 24, 48, 96, 192, 384, 768...: return .white
            case 12: return UIColor(hex: "#776E65")
            default: return .white
            }
        }
    }

    // MARK: - Layout
    enum Layout {
        static let gridSpacing: CGFloat = 8
        static let cellCornerRadius: CGFloat = 8
        static let tileCornerRadius: CGFloat = 6
        static let gridWidthRatio: CGFloat = 0.9

        static func gridSize(in view: SKView) -> CGFloat {
            view.bounds.width * gridWidthRatio
        }

        static func cellSize(gridSize: CGFloat) -> CGFloat {
            (gridSize - 3 * gridSpacing) / 4
        }
    }

    // MARK: - Animation
    enum Animation {
        static let moveDuration: TimeInterval = 0.15
        static let spawnDuration: TimeInterval = 0.15
        static let mergeDuration: TimeInterval = 0.2
    }

    // MARK: - Fonts
    enum Fonts {
        static func tileFont(for value: Int) -> UIFont {
            let size: CGFloat
            if value < 100 {
                size = 48
            } else if value < 1000 {
                size = 40
            } else if value < 10000 {
                size = 32
            } else {
                size = 24
            }
            return UIFont.boldSystemFont(ofSize: size)
        }
    }
}

// MARK: - UIColor Hex Extension
extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized.replaceSubrange(hexSanitized.startIndex...hexSanitized.index(before: hexSanitized.startIndex), with: "#")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
```

- [ ] **Step 2: 验证语法**

Run: `cd /Users/chenjie5/Desktop/claw/game/ai-game-three && swiftc -parse TriYan/DesignSystem.swift 2>&1`
Expected: 无错误

- [ ] **Step 3: 提交**

```bash
git add TriYan/DesignSystem.swift && git commit -m "refactor: rewrite DesignSystem with Threes! colors and layout constants"
```

---

## Task 2: InputController.swift —— 简化滑动识别

**文件：** 重写 `TriYan/InputController.swift`

- [ ] **Step 1: 重写文件**

```swift
import UIKit

enum SwipeDirection {
    case up, down, left, right
}

final class InputController: NSObject {
    var onSwipe: ((SwipeDirection) -> Void)?

    private weak var view: UIView?
    private var panRecognizer: UIPanGestureRecognizer?

    init(view: UIView) {
        self.view = view
        super.init()
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)
        panRecognizer = pan
    }

    deinit {
        if let r = panRecognizer {
            view?.removeGestureRecognizer(r)
        }
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard recognizer.state == .ended else { return }

        let translation = recognizer.translation(in: view)
        let dx = translation.x
        let dy = translation.y
        let threshold: CGFloat = 10

        guard max(abs(dx), abs(dy)) >= threshold else { return }

        if abs(dx) > abs(dy) {
            onSwipe?(dx > 0 ? .right : .left)
        } else {
            onSwipe?(dy > 0 ? .down : .up)
        }
    }
}
```

- [ ] **Step 2: 验证语法**

Run: `swiftc -parse TriYan/InputController.swift 2>&1`
Expected: 无错误

- [ ] **Step 3: 提交**

```bash
git add TriYan/InputController.swift && git commit -m "refactor: simplify InputController to pure swipe detection"
```

---

## Task 3: GameScene.swift —— 核心游戏场景重写

**文件：** 完全重写 `TriYan/GameScene.swift`

### 3.1 重写文件骨架

- [ ] **Step 1: 写入新文件**

完整重写，约 400 行。核心结构：

```swift
import UIKit
import SpriteKit

final class GameScene: SKScene {
    // Model
    private let model = GameModel()
    private let spawner = Spawner()

    // State
    private var tileNodes: [GridPosition: SKLabelNode] = [:]
    private var isAnimating = false
    private var scoreLabel: SKLabelNode?
    private var gridNode: SKNode!

    // Direction mapping from InputController to MoveDirection
    private func direction(for swipe: SwipeDirection) -> MoveDirection {
        switch swipe {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        }
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(hex: "#FAF8EF")
        setupGrid()
        setupScoreLabel()
        startNewGame()
        installInput(on: view)
    }

    // MARK: - Setup

    private func setupGrid() {
        gridNode = SKNode()
        addChild(gridNode)

        let gridSize = DesignSystem.Layout.gridSize(in: view!)
        let cellSize = DesignSystem.Layout.cellSize(gridSize: gridSize)
        let spacing = DesignSystem.Layout.gridSpacing

        for row in 0..<4 {
            for col in 0..<4 {
                let cell = SKShapeNode(rectOf: CGSize(width: cellSize, height: cellSize), cornerRadius: DesignSystem.Layout.cellCornerRadius)
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
        let label = SKLabelNode(fontNamed: "Avenir-Heavy")
        label.fontSize = 24
        label.fontColor = UIColor(hex: "#776E65")
        label.horizontalAlignmentMode = .right
        label.position = CGPoint(x: (view?.bounds.width ?? 400) / 2 - 20, y: (view?.bounds.height ?? 700) / 2 - 20)
        addChild(label)
        scoreLabel = label
    }

    private func startNewGame() {
        model.reset()
        tileNodes.values.forEach { $0.removeFromParent() }
        tileNodes.removeAll()
        spawner.reset(for: model.board)
        spawnTile(at: model.emptyPositions.randomElement()!, value: spawner.takePreviewTile().value)
        spawnTile(at: model.emptyPositions.randomElement()!, value: spawner.takePreviewTile().value)
        updateScore()
    }

    // MARK: - Input

    private func installInput(on view: SKView) {
        let controller = InputController(view: view)
        controller.onSwipe = { [weak self] dir in
            self?.handleSwipe(dir)
        }
    }

    private func handleSwipe(_ swipe: SwipeDirection) {
        guard !isAnimating else { return }
        guard scenePhase == .playing else { return }

        let dir = direction(for: swipe)
        let result = model.move(dir)
        guard result.didMove else {
            // Invalid move - light haptic
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            return
        }

        isAnimating = true

        // Animate movements
        for movement in result.movements {
            if let node = tileNodes[movement.from] {
                let toPos = positionForGrid(movement.to)
                let wait = SKAction.wait(forDuration: DesignSystem.Animation.moveDuration)
                let move = SKAction.move(to: toPos, duration: DesignSystem.Animation.moveDuration)
                move.timingMode = .easeOut
                node.run(SKAction.sequence([move]))
            }
        }

        // Handle merges: move merged-from nodes to target then remove
        for merge in result.merges {
            // Remove the consumed tile nodes (from positions that merged)
            // The target node will be updated with new value
        }

        run(SKAction.wait(forDuration: DesignSystem.Animation.moveDuration)) { [weak self] in
            self?.finishMove(result: result)
        }
    }

    private func finishMove(result: MoveResult) {
        // Rebuild tile nodes from model state
        rebuildTileNodes()

        // Spawn new tile at opposite edge
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
        scaleUp.timingMode = .backOut
        node.run(scaleUp)
    }

    private func makeTileNode(value: Int) -> SKLabelNode {
        let node = SKLabelNode()
        node.text = "\(value)"
        node.fontName = "Avenir-Heavy"
        node.fontSize = DesignSystem.Fonts.tileFont(for: value).pointSize
        node.fontColor = DesignSystem.Colors.tileText(for: value)
        node.verticalAlignmentMode = .center
        node.horizontalAlignmentMode = .center

        let cellSize = DesignSystem.Layout.cellSize(gridSize: DesignSystem.Layout.gridSize(in: view!))
        node.frame = CGRect(x: -cellSize/2, y: -cellSize/2, width: cellSize, height: cellSize)

        // Background
        let bg = SKShapeNode(rectOf: CGSize(width: cellSize, height: cellSize), cornerRadius: DesignSystem.Layout.tileCornerRadius)
        bg.fillColor = DesignSystem.Colors.tileBackground(for: value)
        bg.strokeColor = .clear
        bg.name = "bg"
        node.addChild(bg)
        bg.position = .zero

        return node
    }

    private func rebuildTileNodes() {
        // Remove all existing tile nodes
        tileNodes.values.forEach { $0.removeFromParent() }
        tileNodes.removeAll()

        // Recreate from model
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
        scoreLabel?.text = "\(model.score)"
    }

    // MARK: - Game Over

    private var scenePhase: ScenePhase = .playing
    private var activeOverlay: SKNode?

    private func showGameOver() {
        scenePhase = .gameOver

        let overlay = SKShapeNode(rectOf: CGSize(width: 300, height: 200), cornerRadius: 12)
        overlay.fillColor = UIColor.black.withAlphaComponent(0.5)
        overlay.strokeColor = .clear
        overlay.position = CGPoint(x: 0, y: 0)
        overlay.name = "gameOverOverlay"

        let label = SKLabelNode(text: "游戏结束")
        label.fontSize = 36
        label.fontColor = .white
        label.fontName = "Avenir-Heavy"
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: 40)
        overlay.addChild(label)

        let buttonLabel = SKLabelNode(text: "再来一局")
        buttonLabel.fontSize = 20
        buttonLabel.fontColor = UIColor(hex: "#776E65")
        buttonLabel.fontName = "Avenir-Heavy"
        buttonLabel.verticalAlignmentMode = .center
        buttonLabel.name = "restartButton"
        buttonLabel.position = CGPoint(x: 0, y: -30)
        overlay.addChild(buttonLabel)

        // Button background
        let buttonBg = SKShapeNode(rectOf: CGSize(width: 140, height: 44), cornerRadius: 8)
        buttonBg.fillColor = .white
        buttonBg.strokeColor = .clear
        buttonBg.name = "buttonBg"
        buttonBg.position = CGPoint(x: 0, y: -30)
        overlay.addChild(buttonBg)
        buttonBg.addChild(buttonLabel)
        buttonLabel.position = .zero

        addChild(overlay)
        activeOverlay = overlay
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard scenePhase == .gameOver, let touch = touches.first else { return }
        let location = touch.location(in: self)
        let node = atPoint(location)

        if node.name == "restartButton" || node.name == "buttonBg" {
            hideOverlay()
            startNewGame()
            scenePhase = .playing
        }
    }

    private func hideOverlay() {
        activeOverlay?.removeFromParent()
        activeOverlay = nil
    }
}

private enum ScenePhase {
    case playing
    case gameOver
}
```

> **注意**：以上是核心结构，实际实现时需要根据完整逻辑调整。

- [ ] **Step 2: 验证构建**

Run:
```bash
cd /Users/chenjie5/Desktop/claw/game/ai-game-three
xcodebuild -project TriYan.xcodeproj -scheme TriYan -configuration Debug -sdk iphoneos \
  -destination 'platform=iOS,name=duo2.4' build 2>&1 | grep -E "error:|warning:|BUILD"
```
Expected: 无 error（warning 可接受）

- [ ] **Step 3: 如有错误，修**

常见错误：frame 赋值方式错误、UIColor 和 SKColor 混用、position 计算顺序问题。

- [ ] **Step 4: 提交**

```bash
git add TriYan/GameScene.swift && git commit -m "feat: rewrite GameScene with simple swipe controls and Threes! gameplay"
```

---

## Task 4: 删除废弃文件

**文件：** 删除 `EffectsManager.swift`、`AchievementManager.swift`、`GameCenterService.swift`、`ThemeManager.swift`

- [ ] **Step 1: 删除文件**

```bash
cd /Users/chenjie5/Desktop/claw/game/ai-game-three
rm TriYan/EffectsManager.swift TriYan/AchievementManager.swift TriYan/GameCenterService.swift TriYan/ThemeManager.swift
```

- [ ] **Step 2: 从 Xcode 项目移除引用**

这步需要在 Xcode 中手动操作：打开 Xcode，从项目文件树中删除这四个文件的引用（不要 Move to Trash，选 Remove Reference）。

- [ ] **Step 3: 验证构建**

Run: `xcodebuild ... build 2>&1 | grep -E "error:|BUILD"`

- [ ] **Step 4: 提交**

```bash
git add -A && git commit -m "chore: remove unused systems (effects, achievements, gamecenter, theme)"
```

---

## Task 5: 最终验证与安装

- [ ] **Step 1: 构建**

```bash
cd /Users/chenjie5/Desktop/claw/game/ai-game-three
xcodebuild -project TriYan.xcodeproj -scheme TriYan -configuration Debug \
  -sdk iphoneos -destination 'platform=iOS,name=duo2.4' build install 2>&1 | tail -3
```

- [ ] **Step 2: 确认成功**

Expected: `** BUILD SUCCEEDED **` 和 `** INSTALL SUCCEEDED **`

---

## 自查清单

- [ ] DesignSystem 颜色完整（1-768+ 所有数字）
- [ ] InputController 只有 swipe，无 preview，无复杂状态
- [ ] GameScene 无 drag preview 代码
- [ ] Game Over 正确触发，显示遮罩和按钮
- [ ] 分数实时更新
- [ ] 新 tile 在正确边缘生成（spawnCandidates 对应相反边缘）
- [ ] 无撤销功能
- [ ] 废弃文件已删除

---

## 执行方式

建议 **subagent-driven**：每个 Task 派发给独立 subagent，发现问题立即修复再继续。
