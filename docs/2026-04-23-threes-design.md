# Threes! 游戏重构设计文档

**项目**：ai-game-three（TriYan）
**日期**：2026-04-23
**状态**：设计稿

---

## 一、核心玩法（不变）

- 4×4 网格，滑动合并
- 数字序列：1、2、3、6、12、24、48、96、192、384、768...
- 合成规则：1+2=3，3+3=6，6+6=12，12+12=24...（即除了 1+2=3，其余都是 n+n=2n）
- 新 tile 从滑动方向的相反边缘生成：滑动向上 → 底部随机列；向下滑动 → 顶部随机列；向左滑动 → 右侧随机行；向右滑动 → 左侧随机行。在该行/列中寻找空格，有空格则生成，无空格则该方向无法移动（与 Threes! 原版一致）
- 一次只生成一个新 tile（1 或 2，或当前棋盘上已存在的可合并数字）
- Game Over：4×4 填满且无任何相邻可合并

---

## 二、视觉设计

### 配色

| 数字 | 背景色 | 文字色 |
|------|--------|--------|
| 1 | `#FFFFFF` 白 | `#A39C90` 灰 |
| 2 | `#FF3344` 红 | `#FFFFFF` 白 |
| 3 | `#FF99AA` 粉 | `#FFFFFF` 白 |
| 6 | `#FF7744` 橙 | `#FFFFFF` 白 |
| 12 | `#FFCC33` 黄 | `#776E65` 深灰 |
| 24 | `#DDAA22` 深黄 | `#776E65` |
| 48 | `#BBBB33` 橄榄 | `#FFFFFF` |
| 96 | `#88CC44` 浅绿 | `#FFFFFF` |
| 192 | `#44BB66` 绿 | `#FFFFFF` |
| 384 | `#33AA88` 青 | `#FFFFFF` |
| 768+ | 蓝色系渐变 | `#FFFFFF` |

### 布局

- 屏幕从上到下：顶部栏（标题+分数）→ 游戏网格（居中）
- 网格尺寸：屏幕宽 90%，正方形
- 格子间距：8pt
- 格子圆角：8pt
- 空格子颜色：`#CDC1B4`
- 圆角：Tile 6pt，格子 8pt

### Tile 文字

- 粗体，数字位数少时字号大（1/2/3/6 用 48pt，12 用 40pt，24+ 递减至 24pt）
- 768 及以上用 20pt

### 动画

- **滑动**：Tile 移动到目标位，150ms ease-out
- **合并**：Scale 弹跳 0.8→1.1→1.0，200ms
- **生成**：Scale 从 0→1，150ms
- 动画期间禁止新输入

---

## 三、交互设计

### 滑动操作（最简化）

- 使用 UIPanGestureRecognizer
- 方向判断：|dx| > |dy| → 水平；否则垂直；取绝对值大的方向
- 触发阈值：滑动距离 ≥ 10pt
- 禁止中途换方向（一旦确定方向，整次滑动以此方向为准）
- 滑动手势结束后执行移动，中间不更新 tile 视觉位置（无预览）
- 无效滑动（已无法移动）：触发 UIImpactFeedbackGenerator 轻震动

### 禁止项

- 无撤销功能
- 无预览功能
- 无重新开始按钮（仅 Game Over 后显示"再来一局"）

---

## 四、分数与 UI

### 顶部栏

- 左侧：标题 "Threes!"
- 右侧：当前分数（数字格式，每三位逗号分隔）
- 字号：标题 28pt Bold，分数 24pt Bold，颜色 `#776E65`

### Game Over

- 触发：网格填满且无任何可合并
- 显示：半透明黑色遮罩 alpha=0.5
- 内容居中："游戏结束"（白色，36pt）+"再来一局"按钮
- 按钮样式：白底黑字，圆角 8pt，padding 16pt，点击区域足够大
- 点击按钮重置棋盘，重新开始

---

## 五、代码重构目标

### 保留的部分

- GameModel.swift：游戏逻辑核心（board、move、spawn、gameOver 判断）
- Spawner.swift：tile 生成逻辑（可能需调整以支持前沿生成）
- Tile.swift：数据模型

### 重写的部分

- **GameScene.swift**：从 1774 行精简到 ~500 行
  - 去掉 drag preview 相关逻辑
  - 去掉 InputController 的 pan 预览逻辑（改用最简单的 swipe 感知）
  - 重新实现滑动方向判断（简化）
  - 合并动画和生成动画独立简洁
  - 分数显示简化

- **InputController.swift**：简化到 ~50 行
  - 只保留 pan 手势识别
  - 方向判断逻辑独立
  - 无 preview、无 saved positions、无 direction locking 复杂逻辑

- **DesignSystem.swift**：配色常量集中管理

- **GameViewController.swift**：保持最小化

### 删除的部分

- EffectsManager.swift（粒子特效删除）
- AchievementManager.swift（成就系统删除）
- GameCenterService.swift（Game Center 删除）
- ThemeManager.swift（主题系统删除）

---

## 六、技术约束

- 目标设备：iOS 真机（duo2.4）
- SDK：iphoneos
- 构建：xcodebuild -sdk iphoneos -destination 'platform=iOS,name=duo2.4'
- 框架：SpriteKit + UIKit（GameViewController 承载 SKView）
- 音频：AudioManager 保留但本次不使用

---

## 七、实现顺序

1. GameScene.swift 完全重写（核心）
2. InputController.swift 简化
3. DesignSystem.swift 建立配色常量
4. GameViewController.swift 确认入口
5. 清理废弃文件
6. Build + Install 到 duo2.4 测试
