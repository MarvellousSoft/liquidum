# Gemini Agent Instructions: Liquidum (`project/`)

## Project Overview

This directory (`project/`) contains the Godot source code for **Liquidum**, a puzzle game. It is published on Steam, Google Play, and the App Store.

### Relation to `lite-web/`
This repository also contains `lite-web/`, which is a lightweight Web/TypeScript port of the game's core logic and UI. The core puzzle engine (`project/game/level/grid/GridImpl.gd`, `Enums.gd`, etc.) is exactly ported to `lite-web/src/engine/`. Changes to core logic here may need to be reflected in the web port, and vice-versa.

---

## Technical Specifications

1. **Godot Version Lock**:
   - The project is firmly locked to **Godot 4.1.3**.
   - Do NOT attempt to upgrade the project to 4.2+ or 4.3+. This is due to a known Godot engine issue (https://github.com/godotengine/godot/issues/85695).

2. **Core Puzzle Engine (`game/level/grid/`)**:
   - `GridImpl.gd`: Handles the physics, logic, flooding (DFS), rule validation, and core loop of the grid.
   - `Grid.gd`: Handles the visual and UI representation of the grid in Godot.
   - `Enums.gd`: (Autoload `E`) Contains enumerations for cell states (Water, Air, Boat, MaybeBoat, etc.), shapes (Single, Diagonals), and hint types.
   - `TestRunner.gd` / `GridTests.gd`: Contains tests for the puzzle engine logic.
   
3. **Levels Database (`database/levels/`)**:
   - Contains the JSON definitions and mappings for the game's puzzles.
   
4. **Localization (`localization/`)**:
   - Translations are managed through `localizations.csv`.
   - `LocalizationManager.gd` is an autoload handling current language and string resolution.

5. **Key Autoloads / Singletons** (from `project.godot`):
   - `Global`: General game state and global variables.
   - `AudioManager`: Global sound effects and music manager.
   - `FileManager` / `Profile`: Handles saving, loading, and player progression.
   - `TransitionManager`: Screen transitions.
   - `PlayFabManager` / `SteamManager` / `GooglePlayGameServices` / `FacebookManager` / `AdManager`: External API wrappers for progression, achievements, leaderboards, and ads.

6. **Plugins (`addons/`)**:
   - The game heavily relies on plugins for monetization, progression, and platform features.
   - **Android Plugins**: Godot AdMob, Google Play Game Services, Facebook SDK, Local Notifications.
   - **Multiplatform**: Godot-Playfab (backend/leaderboards), GodotSteam (PC achievements/workshop).

---

## Game Rules & Mechanics (Picross-like)

Liquidum is fundamentally a logic puzzle similar to **Picross / Nonograms**, but instead of filling pixels to create a picture, the player fills a grid with Water (and Boats) by following numerical clues and simulated physical rules.

### 1. Aquariums & Gravity
- The grid is divided by thick borders into irregularly shaped containers called **Aquariums**.
- **Gravity**: Water cannot float in mid-air. When placed in an aquarium, water automatically falls to fill the lowest available cells within that specific aquarium's bounds. Flooding is simulated from the bottom up (using a DFS algorithm).

### 2. Line Hints (Row & Column Clues)
Numbers outside the grid indicate the exact number of water cells (or boats) required in that row or column.
- `N` (e.g., `3`): Exactly `N` water cells in this line.
- `{N}` (**Together**): Exactly `N` water cells, and they must form a single **contiguous** block (no air gaps between them in that line).
- `-N-` (**Separate**): Exactly `N` water cells, but they must **NOT** be contiguous (there must be at least one air gap separating them).
- `?` (**Unknown**): The number of water cells is unknown (but must be at least 1).
- `{?}` / `-?-`: Unknown number of waters, but they must be contiguous / separated, respectively.

### 3. Boats
- Boats take up exactly 1 cell and float on top of water.
- The cell directly below any boat **must** contain water.
- There can be separate line hints indicating the exact number of boats in a row/col (can also use `?`, `{N}`, `-N-`).

### 4. Diagonals
- Diagonal walls (`/` or `\`) split a single square cell into two triangular halves.
- Each filled triangular half counts as **0.5 waters**.
- Water still obeys gravity within these half-cells (e.g., filling the bottom triangle before the top).

### 5. Advanced & Global Hints
- **Aquarium Hints**: A global rule indicating how many aquariums contain a specific amount of water across the entire grid (e.g., "There is 1 aquarium with exactly 3 water cells"). These are rendered as small cards in the UI.
- **Cell Hints (Minesweeper-style)**: A number placed directly inside a grid cell indicating the total amount of water in the 9 adjacent cells (the 3x3 area centered on that cell).
- **Total Stats**: Global limits on the total number of water cells or boats allowed in the entire puzzle.

---

## Agent Workflow & Best Practices

1. **Preserving Compatibility**:
   - Always write GDScript compatible with **Godot 4.1**. Avoid features introduced in 4.2 or 4.3.
2. **Editing Files**:
   - When modifying `.tscn` (scene) files directly via text editor, be extremely careful not to break Node references or external resource IDs.
   - Prefer modifying `.gd` scripts. If major scene changes are required, advise the user on how to do it in the Godot Editor.
3. **Running Tests**:
   - The project includes tests in `game/level/grid/`. When modifying core engine logic (`GridImpl.gd`), try to run or update `TestRunner.tscn`.
4. **Platform Specifics**:
   - Be mindful of platform checks (e.g., `OS.get_name() == "Android"` or `"iOS"`) since this game is multi-platform. Use the appropriate autoloads (`AdManager`, `GooglePlayGameServices`, `SteamManager`) carefully.
