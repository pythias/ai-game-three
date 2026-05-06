# Hex Grid Refactor Design

Date: 2026-05-06

## Goal

Refactor TriYan from a 4x4 square-grid puzzle into a true pointy-top hexagonal honeycomb puzzle matching `docs/hex-grid.md` and the provided reference image.

The finished game should use a symmetric `3 / 4 / 5 / 4 / 3` board, real six-direction movement, and a polished blue mobile-game UI. The visual board and movement logic must be the same geometry; hex tiles on square-grid logic is out of scope.

## Gameplay

- The board contains 19 valid cells arranged as rows with counts `3, 4, 5, 4, 3`.
- Every cell is a pointy-top regular hexagon with the same orientation.
- Movement supports six directions:
  - east
  - west
  - northeast
  - southwest
  - northwest
  - southeast
- A swipe maps to the nearest of those six directions.
- A move compresses each hex line toward the swipe direction, merging adjacent compatible tiles once per move.
- Merge rules stay unchanged:
  - `1 + 2 = 3`
  - `2 + 1 = 3`
  - values `>= 3` merge only with the same value and double.
- Scoring remains the sum of newly created merge values.
- New tiles spawn from empty cells on the edge opposite the movement direction when possible, falling back to any empty cell if the edge is full.
- Game over means the board is full and no neighboring hex pair can merge in any of the six directions.

## Data Model

`GameModel` should replace fixed-size array indexing with a set of valid hex coordinates and a dictionary-backed cell store.

`GridPosition` will remain the shared key type, but its fields will represent axial coordinates:

- `row` stores axial `r`
- `col` stores axial `q`

This keeps the public type stable while allowing true hex-grid math. The valid board radius is 2, yielding 19 positions where `max(abs(q), abs(r), abs(-q-r)) <= 2`.

The row presentation for UI will be derived from valid axial coordinates and ordered visually as:

```text
    3
   4
  5
   4
    3
```

Snapshots used by stats and history will store 19 values in deterministic visual row order. Legacy 16-value snapshots remain readable by padding or truncating during rendering.

## Rendering

`GameScene` should render a real honeycomb:

- Use pointy-top hex geometry for empty cells and tile textures.
- Compute cell centers using pointy-top axial projection:
  - `x = hexWidth * (q + r / 2)`
  - `y = -verticalStep * r`
- Derive hex size from available screen width and height so the board fits portrait layouts.
- Use row offsets only as a visual consequence of axial projection, not as square-grid positioning.
- Replace square rounded tile textures with regular hex tile textures, keeping glossy gradients, highlights, bevel strokes, soft shadows, and readable rounded numbers.
- Rebuild history board snapshots as miniature hex boards.

## UI Layout

The main scene should move toward the provided screenshot:

- Blue radial/linear full-screen background.
- Top-left coin counter card with coin icon, count, and plus button.
- Top-center best score glossy card.
- Top-right circular settings button.
- Center score panel above the board with large score text.
- Board centered and sized prominently.
- Floating merge feedback near the board, including `+score`, glow, particles, and merge pulse.
- Bottom restart and hint buttons styled as glossy rounded controls.
- Hint button includes a red notification badge. The initial implementation may keep hint as a UI action placeholder unless a real hint solver is explicitly requested.

Existing menu, settings, history, Game Center, audio, and stats behavior should remain functional unless directly contradicted by the new board geometry.

## Input

`InputController` should classify pan gestures into six hex directions instead of four square directions. It should use the pan vector angle and choose the closest direction among east, west, northeast, southwest, northwest, and southeast.

Menu overlay swipe navigation can keep using horizontal left/right semantics by mapping compatible hex swipe directions or by exposing a separate overlay-friendly direction if needed.

## Error Handling And Compatibility

- Invalid positions should be ignored safely by `tile(at:)`, `place`, and internal model helpers.
- Spawn logic should never crash if preferred edge candidates are unavailable.
- Stats/history rendering should tolerate nil, 16-value, 19-value, and longer snapshots.
- Existing best score, achievements, and audio behavior should continue to work with the new board.

## Testing

Verification should include:

- Build the Xcode project with `xcodebuild`.
- Model-level sanity checks through compile-time usage and local helper tests if practical:
  - board has 19 valid positions
  - movement works in all six directions
  - compatible adjacent hex tiles merge
  - game-over checks all six neighbor directions
- Visual smoke check in simulator or by running the app if available.

## Non-Goals

- No fake hex presentation on top of square movement.
- No new real-money coin economy.
- No full hint solver unless requested separately.
- No redesign of Game Center achievement definitions beyond compatibility with the 19-cell board.
