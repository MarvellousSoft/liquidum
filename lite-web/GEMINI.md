# Gemini Agent Instructions: Liquidum Lite (`lite-web`)

## Project Overview

`lite-web` is a lightweight web implementation and partial port of the puzzle game **Liquidum**, originally built in the **Godot engine** (located in the `project/` directory of this repository).

### Relationship to the Original Godot Game
- **Core Puzzle Engine**: The logic in `src/engine/` (`GridImpl.ts`, `Grid.ts`, `E.ts`) is a direct TypeScript port of the Godot GDScript implementation (`project/game/level/grid/GridImpl.gd`, `E.gd`, etc.).
- **Data Models & Level Formats**: Grid models, level parsing, and rule verification in `src/model/GridData.ts` follow `project/game/level/grid/GridModel.gd` and the level JSON definitions in `project/database/levels/`.
- **UI & Presentation**: Built with **Preact** and **Vanilla CSS** (`src/app.tsx`, `src/components/`, `src/index.css`), faithfully preserving the mechanics, design language, responsive layout, and visual feedback of the original game.

---

## How It Works

1. **Grid & Cells**:
   - The board consists of cells that can be `Single` (full 1.0 square), `IncDiag` (increasing diagonal `/`), or `DecDiag` (decreasing diagonal `\`).
   - Cell content types include `Water`, `NoWater` (Air / ✕), `Boat` (⛵), `NoBoat` (Maybe Boat / ?), `Block` (solid rock), and `Nothing` (empty).
   - Diagonals are divided into two triangular halves addressed by corners (`TopLeft`, `TopRight`, `BottomLeft`, `BottomRight`).

2. **Physics & Flooding**:
   - Water adheres to gravity and container flooding: placing water fills connected container volumes from the bottom up using Depth-First Search (`AddWaterDfs`).
   - Boats float on water cells. Water and boat counts are strictly independent.

3. **Hints & Constraints**:
   - **Row / Column Hints**: Water hints display target water counts and optional togetherness decorators (`{count}` for Together, `-count-` for Separated). Boat hints track row/column boat counts.
   - **Header Stats**: Overall total water, total boats, and aquarium counts are displayed when defined for the level.
   - **Level Completion**: `isLevelComplete` validates that all row/col water hints, boat hints, total stats, and aquarium targets are satisfied. Air placement is optional for winning.

4. **Context-Aware Tool Toolbar**:
   - Matching the original game (`project/game/level/Level.gd`), tools are shown dynamically only when relevant to the current level:
     - If a level has no boats (no boat hints and `total_boats <= 0`), the boat and maybeboat tools are hidden, and shortcuts `'3'` and `'4'` are disabled.

---

## Agent Instructions & Testing Workflow

When fixing an issue or adding a feature:
1. **First add a test if possible**:
   - Add a **unit test** (`npm run test:unit` via Vitest in `tests/`) if it is not a visual thing (e.g. logic, grid calculations, physics, hint validation, parser rules).
   - Add a **Playwright test** (`npm run test:e2e` in `e2e/`) if it is a visual or user-interaction thing (e.g. UI layout, styles, DOM attributes, clicks, toolbar visibility).
2. **Make sure it becomes green**:
   - Verify that the test initially fails (if fixing a bug or adding a feature), implement the change cleanly, and then make sure all tests pass.
3. **Gemini Browser Usage**:
   - **Only use the Gemini browser to test it when a test is not possible, or when the new feature is substantially big.**

---

## Useful Commands

Run from `lite-web/`:
```bash
# Run all tests (unit + E2E)
npm test

# Run unit tests only (Vitest)
npm run test:unit

# Run a specific unit test file
npm run test:unit -- tests/water-boat-hints.test.ts

# Run E2E & visual tests (Playwright)
npm run test:e2e

# Run a specific Playwright test by title
npm run test:e2e -- -g "visual_test_only_show_relevant_tools_for_current_level"

# Start Vite dev server
npm run dev
```
