import { test, expect } from '@playwright/test';

test.describe('Visual & Interactive Gameplay Tests', () => {

  test.beforeEach(async ({ page }) => {
    // Open in standalone test mode (no top level picker buttons)
    await page.goto('/?mode=test');
    await expect(page.locator('[data-testid="tool-water"]')).toBeVisible();
    await expect(page.locator('[data-testid="btn-restart"]')).toBeVisible();
  });

  test('visual_test_screen_has_no_level_picker_buttons_in_test_mode', async ({ page }) => {
    // Confirm that the top level buttons (01/01, etc.) are NOT displayed
    const level01Btn = page.locator('button:has-text("Level 01/01")');
    await expect(level01Btn).toHaveCount(0);

    // Tools and grid are visible (Level 01/01 has no boats, so boat tool is not visible)
    await expect(page.locator('[data-testid="tool-water"]')).toBeVisible();
    await expect(page.locator('[data-testid="tool-air"]')).toBeVisible();
    await expect(page.locator('[data-testid="tool-boat"]')).toHaveCount(0);
    await expect(page.locator('[data-testid="cell-0-0"]')).toBeVisible();
  });

  test('visual_test_put_water_and_gravity (adapted from test_put_water_one_cell)', async ({ page }) => {
    // 2x2 grid (4 lines: line 0 contents, line 1 walls, line 2 contents, line 3 walls)
    const emptyGrid = `
....
....
....
L...
`;
    await page.evaluate((lvl) => (window as any).loadLevelString(lvl, false), emptyGrid);

    // Check initial state: cells are empty
    await expect(page.locator('[data-testid="cell-0-0"]')).toHaveAttribute('data-content-left', 'none');
    await expect(page.locator('[data-testid="cell-1-0"]')).toHaveAttribute('data-content-left', 'none');

    // Click tool water to be sure
    await page.click('[data-testid="tool-water"]');

    // Click cell (0, 0)
    await page.click('[data-testid="cell-0-0"]');

    // Cell (0, 0) and (1, 0) should both fill with water due to gravity
    await expect(page.locator('[data-testid="cell-0-0"]')).toHaveAttribute('data-content-left', 'water');
    await expect(page.locator('[data-testid="cell-1-0"]')).toHaveAttribute('data-content-left', 'water');

    // Visual check: cells have water background styling
    const waterDiv = page.locator('[data-testid="cell-0-0"] div.cell-water');
    await expect(waterDiv).toBeVisible();
  });

  test('visual_test_right_click_air (adapted from test_remove_water_bug)', async ({ page }) => {
    const emptyGrid = `
....
....
....
....
`;
    await page.evaluate((lvl) => (window as any).loadLevelString(lvl, false), emptyGrid);

    // Initial check: cell (0, 1) is empty
    await expect(page.locator('[data-testid="cell-0-1"]')).toHaveAttribute('data-content-left', 'none');

    // Right-click cell (0, 1) to mark Air (✕)
    await page.click('[data-testid="cell-0-1"]', { button: 'right' });

    // Cell (0, 1) should now have air
    await expect(page.locator('[data-testid="cell-0-1"]')).toHaveAttribute('data-content-left', 'air');
    await expect(page.locator('[data-testid="cell-0-1"]')).toContainText('✕');

    // Right-click again toggles back to none
    await page.click('[data-testid="cell-0-1"]', { button: 'right' });
    await expect(page.locator('[data-testid="cell-0-1"]')).toHaveAttribute('data-content-left', 'none');
    await expect(page.locator('[data-testid="cell-0-1"]')).not.toContainText('✕');
  });

  test('visual_test_air_tool_left_click_placement (mobile friendly)', async ({ page }) => {
    const emptyGrid = `
....
....
....
....
`;
    await page.evaluate((lvl) => (window as any).loadLevelString(lvl, false), emptyGrid);

    // Initial check: cell (0, 1) is empty
    await expect(page.locator('[data-testid="cell-0-1"]')).toHaveAttribute('data-content-left', 'none');

    // Select Air tool
    await page.click('[data-testid="tool-air"]');

    // Normal left-click on cell (0, 1) to mark Air (✕) without right-click
    await page.click('[data-testid="cell-0-1"]');

    // Cell (0, 1) should now have air
    await expect(page.locator('[data-testid="cell-0-1"]')).toHaveAttribute('data-content-left', 'air');
    await expect(page.locator('[data-testid="cell-0-1"]')).toContainText('✕');

    // Left-click again toggles back to none
    await page.click('[data-testid="cell-0-1"]');
    await expect(page.locator('[data-testid="cell-0-1"]')).toHaveAttribute('data-content-left', 'none');
    await expect(page.locator('[data-testid="cell-0-1"]')).not.toContainText('✕');
  });

  test('visual_test_air_tool_on_diagonal_tile', async ({ page }) => {
    // Load Level 03/01 which contains diagonal cells (e.g. cell 0,0 is IncDiag)
    await page.evaluate(() => (window as any).loadLevelKey("Level 03/01"));

    const diagCell = page.locator('[data-testid="cell-0-0"]');
    await expect(diagCell).toHaveAttribute('data-cell-type', '9');
    await expect(diagCell).toHaveAttribute('data-content-left', 'none');
    await expect(diagCell).toHaveAttribute('data-content-right', 'none');

    // Select the Air tool
    await page.click('[data-testid="tool-air"]');

    // Click top-left corner of the diagonal cell
    const box = await diagCell.boundingBox();
    expect(box).not.toBeNull();
    await page.click('[data-testid="cell-0-0"]', { position: { x: 6, y: 6 } });

    // Top-left content is now air
    await expect(diagCell).toHaveAttribute('data-content-left', 'air');
    await expect(diagCell).toHaveAttribute('data-content-right', 'none');

    // Air sprite rendered inside diagonal layer with air-sprite-diagonal class
    const airSpriteTL = diagCell.locator('img.air-sprite-diagonal');
    await expect(airSpriteTL).toBeVisible();

    // Click bottom-right corner of the diagonal cell
    await page.click('[data-testid="cell-0-0"]', { position: { x: box!.width - 6, y: box!.height - 6 } });

    // Bottom-right content is now also air
    await expect(diagCell).toHaveAttribute('data-content-left', 'air');
    await expect(diagCell).toHaveAttribute('data-content-right', 'air');

    // Two diagonal air sprites now visible
    await expect(diagCell.locator('img.air-sprite-diagonal')).toHaveCount(2);

    // Click top-left again to toggle back to none
    await page.click('[data-testid="cell-0-0"]', { position: { x: 6, y: 6 } });
    await expect(diagCell).toHaveAttribute('data-content-left', 'none');
    await expect(diagCell).toHaveAttribute('data-content-right', 'air');
    await expect(diagCell.locator('img.air-sprite-diagonal')).toHaveCount(1);
  });

  test('visual_test_caves_and_aquarium_flooding (adapted from test_water_big_level)', async ({ page }) => {
    // 3-column, 2-row grid with connected bottom aquarium bucket
    // Note: each cell in the wall line has 2 characters (wall type + diag type, e.g. "L.", "_.", "..")
    const bucketLevel = `
......
......
......
L._...
`;
    await page.evaluate((lvl) => (window as any).loadLevelString(lvl, false), bucketLevel);

    await page.click('[data-testid="tool-water"]');
    // Click top-left cell (0, 0)
    await page.click('[data-testid="cell-0-0"]');

    // Bottom-left (1, 0) and bottom-middle (1, 1) form a connected bucket, flooded by gravity
    await expect(page.locator('[data-testid="cell-1-0"]')).toHaveAttribute('data-content-left', 'water');
    await expect(page.locator('[data-testid="cell-1-1"]')).toHaveAttribute('data-content-left', 'water');
  });

  test('visual_test_boat_placement_and_water (adapted from test_boat_place_remove)', async ({ page }) => {
    // 2x2 grid with walls below row 1 and +boats=1 declaration
    const gridWithWalls = `
+boats=1
....
....
....
L._.
`;
    await page.evaluate((lvl) => (window as any).loadLevelString(lvl, false), gridWithWalls);

    // Select the boat tool
    await page.click('[data-testid="tool-boat"]');

    // Place boat at cell (0, 0)
    await page.click('[data-testid="cell-0-0"]');

    // Cell (0, 0) should show boat
    await expect(page.locator('[data-testid="cell-0-0"]')).toHaveAttribute('data-content-left', 'boat');
    await expect(page.locator('[data-testid="cell-0-0"]')).toContainText('⛵');

    // Placing a boat automatically puts water beneath it in cell (1, 0)
    await expect(page.locator('[data-testid="cell-1-0"]')).toHaveAttribute('data-content-left', 'water');

    // The water cell beneath the boat retains its surface foam
    await expect(page.locator('[data-testid="cell-1-0"] .cell-water')).toHaveClass(/is-surface/);
  });

  test('visual_test_victory_banner_and_grid_lock', async ({ page }) => {
    // Load Level 01/01 (3x3 grid with walls between cells)
    await page.evaluate(() => (window as any).loadLevelKey("Level 01/01"));

    // Ensure victory banner is not yet visible
    await expect(page.locator('[data-testid="win-banner"]')).not.toBeVisible();

    // Mark air (✕) in the 3 non-water cells
    await page.click('[data-testid="cell-0-0"]', { button: 'right' });
    await page.click('[data-testid="cell-1-0"]', { button: 'right' });
    await page.click('[data-testid="cell-1-1"]', { button: 'right' });

    // Select water tool
    await page.click('[data-testid="tool-water"]');

    // Fill the 6 water cells:
    // row 0: (0, 1), (0, 2)
    // row 1: (1, 2)
    // row 2: (2, 0), (2, 1), (2, 2)
    await page.click('[data-testid="cell-0-1"]');
    await page.click('[data-testid="cell-0-2"]');
    await page.click('[data-testid="cell-1-2"]');
    await page.click('[data-testid="cell-2-0"]');
    await page.click('[data-testid="cell-2-1"]');
    await expect(page.locator('[data-testid="win-banner"]')).toBeHidden();
    await page.click('[data-testid="cell-2-2"]');

    // Level is now fully solved and completed!
    await expect(page.locator('[data-testid="win-banner"]')).toBeVisible();
    await expect(page.locator('[data-testid="win-banner"]')).toContainText('Level Complete!');

    // Check that grid container has pointer-events-none applied
    const lockedGrid = page.locator('.pointer-events-none [data-testid="cell-0-0"]');
    await expect(lockedGrid).toBeVisible();

    // Verify clicks on cells don't alter state when locked
    await page.click('[data-testid="cell-0-0"]', { force: true });
    await expect(page.locator('[data-testid="cell-0-0"]')).toHaveAttribute('data-content-left', 'air');

    // Click 'Play Again' button
    await page.click('[data-testid="btn-play-again"]');

    // Verify win banner disappears and cells reset
    await expect(page.locator('[data-testid="win-banner"]')).not.toBeVisible();
    await expect(page.locator('[data-testid="cell-0-1"]')).toHaveAttribute('data-content-left', 'none');
    await expect(page.locator('[data-testid="cell-2-2"]')).toHaveAttribute('data-content-left', 'none');
  });

  test('visual_test_victory_without_marking_airs', async ({ page }) => {
    // Load Level 01/01 without marking any airs
    await page.evaluate(() => (window as any).loadLevelKey("Level 01/01"));

    await expect(page.locator('[data-testid="win-banner"]')).not.toBeVisible();

    // Select water tool
    await page.click('[data-testid="tool-water"]');

    // Fill the 6 water cells directly without touching any air cells
    await page.click('[data-testid="cell-0-1"]');
    await page.click('[data-testid="cell-0-2"]');
    await page.click('[data-testid="cell-1-2"]');
    await page.click('[data-testid="cell-2-0"]');
    await page.click('[data-testid="cell-2-1"]');
    await expect(page.locator('[data-testid="win-banner"]')).toBeHidden();
    await page.click('[data-testid="cell-2-2"]');

    // Victory should immediately trigger because all hints are satisfied
    await expect(page.locator('[data-testid="win-banner"]')).toBeVisible();
    await expect(page.locator('[data-testid="win-banner"]')).toContainText('Level Complete!');

    // The non-water cells should still be untouched ('none')
    await expect(page.locator('[data-testid="cell-0-0"]')).toHaveAttribute('data-content-left', 'none');
    await expect(page.locator('[data-testid="cell-1-0"]')).toHaveAttribute('data-content-left', 'none');
    await expect(page.locator('[data-testid="cell-1-1"]')).toHaveAttribute('data-content-left', 'none');
  });

  test('visual_test_total_water_hint_counter', async ({ page }) => {
    // Load Level 01/05 which has a total water hint of 7
    await page.evaluate(() => (window as any).loadLevelKey("Level 01/05"));

    const waterCounter = page.locator('[data-testid="hint-water-counter"]');
    await expect(waterCounter).toBeVisible();
    await expect(waterCounter).toContainText('0 / 7');
    await expect(waterCounter).not.toContainText('left');

    // Click tool water and fill isolated 1x1 bucket cell (0, 0)
    await page.click('[data-testid="tool-water"]');
    await page.click('[data-testid="cell-0-0"]');

    // Cell (0, 0) has walls around it, adding exactly 1 water
    await expect(waterCounter).toContainText('1 / 7');
    await expect(waterCounter).not.toContainText('left');
    await expect(waterCounter).toHaveClass(/hint-stat-normal/);
  });

  test('visual_test_total_boats_counter', async ({ page }) => {
    // Load Level 04/05 which features total boats (2)
    await page.evaluate(() => (window as any).loadLevelKey("Level 04/05"));

    const boatCounter = page.locator('[data-testid="hint-boat-counter"]');
    await expect(boatCounter).toBeVisible();
    await expect(boatCounter).toContainText('0 / 2');
    await expect(boatCounter).not.toContainText('left');

    // Select boat tool and place boat in cell (0, 5) which is a solution boat
    await page.click('[data-testid="tool-boat"]');
    await page.click('[data-testid="cell-0-5"]');

    await expect(boatCounter).toContainText('1 / 2');
    await expect(boatCounter).not.toContainText('left');
  });

  test('visual_test_aquarium_hints_visual_tanks_and_satisfaction', async ({ page }) => {
    // Load Level 05/08 which features aquariums (0.5 x 1, 1 x 2)
    await page.evaluate(() => (window as any).loadLevelKey("Level 05/08"));

    const aqSection = page.locator('[data-testid="aquarium-section"]');
    await expect(aqSection).toBeVisible();
    const halfTank = page.locator('[data-testid="aquarium-hint-0.5"]');
    await expect(halfTank).toBeVisible();
    await expect(halfTank).toContainText('0.5');
    await expect(halfTank).not.toContainText('½');
    await expect(page.locator('[data-testid="aquarium-hint-1"]')).toBeVisible();

    // Fill top-left diagonal of cell (0, 0)
    await page.click('[data-testid="tool-water"]');
    await page.click('[data-testid="cell-0-0"]', { position: { x: 5, y: 5 } });

    // The 0.5 aquarium hint should immediately be satisfied
    await expect(halfTank).toHaveClass(/aquarium-card-satisfied/);
    await expect(halfTank).toContainText('✓ 1');
  });

  test('visual_test_maybeboat_tool_and_cell_placement', async ({ page }) => {
    // Level 04/05 has boats, so maybeboat tool is visible
    await page.evaluate(() => (window as any).loadLevelKey("Level 04/05"));

    const maybeTool = page.locator('[data-testid="tool-maybeboat"]');
    await expect(maybeTool).toBeVisible();
    await maybeTool.click();
    await expect(maybeTool).toHaveClass(/tool-btn-maybeboat-active/);

    // Place MaybeBoat on cell (0, 5)
    await page.click('[data-testid="cell-0-5"]');
    const cell = page.locator('[data-testid="cell-0-5"]');
    await expect(cell.locator('.cell-maybeboat')).toBeVisible();
    await expect(cell).toHaveAttribute('data-content-left', 'noboat');

    // Click again to remove
    await page.click('[data-testid="cell-0-5"]');
    await expect(cell.locator('.cell-maybeboat')).not.toBeVisible();
    await expect(cell).toHaveAttribute('data-content-left', 'none');
  });

  test('visual_test_level_06_03_hints_layout_nowrap', async ({ page }) => {
    await page.evaluate(() => (window as any).loadLevelKey("Level 06/03"));
    const gridContainer = page.locator('.has-dual-row-hints');
    await expect(gridContainer).toBeVisible();

    // Verify row 1 has both hints without text breaking
    const rowHints = page.locator('.row-hint');
    await expect(rowHints.nth(0)).toContainText('0');
    await expect(rowHints.nth(1)).toContainText('?');
  });

  test('visual_test_level_04_05_boat_does_not_break_water_hint_and_solves', async ({ page }) => {
    await page.evaluate(() => (window as any).loadLevelKey("Level 04/05"));

    const row0Hint = page.locator('.row-hint').nth(0).locator('span.hint-satisfied-water, span.hint-normal, span.hint-over');
    await expect(row0Hint).toContainText('4');

    // Fill water to satisfy Row 0 hint {4}:
    // Left container: (2,0), (2,1), (1,0), (1,1), (0,0), (0,1)
    // Middle container: (2,2), (1,2), (0,2), (0,3)
    await page.evaluate(() => {
      const put = (window as any).putCellAction;
      put(2, 0, 5, 1);
      put(2, 1, 5, 1);
      put(1, 0, 5, 1);
      put(1, 1, 5, 1);
      put(0, 0, 8, 1);
      put(0, 0, 6, 1);
      put(0, 1, 5, 1);
      put(2, 2, 5, 1);
      put(1, 2, 5, 1);
      put(0, 2, 5, 1);
      put(0, 3, 5, 1);
    });

    // Hint {4} should now be green (satisfied)
    await expect(row0Hint).toHaveClass(/hint-satisfied-water/);
    await expect(row0Hint).not.toHaveClass(/hint-over/);

    // Place boat at cell (0, 5) using interactive boat tool
    await page.click('[data-testid="tool-boat"]');
    await page.click('[data-testid="cell-0-5"]');

    // CRITICAL REQUIREMENT: Row 0 hint {4} must STILL be satisfied/green, and NOT red/hint-over!
    await expect(row0Hint).toHaveClass(/hint-satisfied-water/);
    await expect(row0Hint).not.toHaveClass(/hint-over/);

    // Verify boat counter shows 1 / 2
    const boatCounter = page.locator('[data-testid="hint-boat-counter"]');
    await expect(boatCounter).toContainText('1 / 2');

    // Complete remaining water for the puzzle:
    await page.evaluate(() => {
      const put = (window as any).putCellAction;
      put(2, 3, 7, 1);
      put(2, 4, 5, 1);
      put(2, 5, 5, 1);
      put(1, 5, 6, 1);
    });

    // Place second boat at cell (1, 3) to complete the level
    await page.click('[data-testid="cell-1-3"]');
    await expect(boatCounter).toContainText('2 / 2');
    await expect(boatCounter).toHaveClass(/hint-stat-satisfied/);

    // Level should be completed!
    await expect(page.locator('[data-testid="win-banner"]')).toBeVisible();
    await expect(page.locator('[data-testid="win-banner"]')).toContainText('Level Complete');
  });

  test('visual_test_total_boats_counter_natural_styling_when_satisfied', async ({ page }) => {
    await page.evaluate(() => (window as any).loadLevelKey("Level 04/05"));

    const boatCounter = page.locator('[data-testid="hint-boat-counter"]');
    await expect(boatCounter).toHaveClass(/hint-stat-normal/);

    // Place 2 boats
    await page.click('[data-testid="tool-boat"]');
    await page.click('[data-testid="cell-0-5"]');
    await page.click('[data-testid="cell-1-3"]');

    // When complete, becomes green
    await expect(boatCounter).toHaveClass(/hint-stat-satisfied/);
    await expect(boatCounter).toContainText('2 / 2');
    await expect(boatCounter.locator('.badge-satisfied')).toBeVisible();

    // Verify text is white/light and NOT dark navy / black blob
    const valueEl = boatCounter.locator('.hint-stat-value');
    const color = await valueEl.evaluate((el) => window.getComputedStyle(el).color);
    // rgb(255, 255, 255) is white
    expect(color).toBe('rgb(255, 255, 255)');
  });

  test('visual_test_only_show_relevant_tools_for_current_level', async ({ page }) => {
    // 1. Level 01/01 has no boats: boat tools must NOT be shown
    await page.evaluate(() => (window as any).loadLevelKey("Level 01/01"));
    await expect(page.locator('[data-testid="tool-water"]')).toBeVisible();
    await expect(page.locator('[data-testid="tool-air"]')).toBeVisible();
    await expect(page.locator('[data-testid="tool-boat"]')).toHaveCount(0);
    await expect(page.locator('[data-testid="tool-maybeboat"]')).toHaveCount(0);

    // 2. Level 04/05 has boats: boat and maybeboat tools MUST be shown
    await page.evaluate(() => (window as any).loadLevelKey("Level 04/05"));
    await expect(page.locator('[data-testid="tool-water"]')).toBeVisible();
    await expect(page.locator('[data-testid="tool-air"]')).toBeVisible();
    await expect(page.locator('[data-testid="tool-boat"]')).toBeVisible();
    await expect(page.locator('[data-testid="tool-maybeboat"]')).toBeVisible();

    // 3. Switch back to a level without boats (e.g. Level 02/01): boat tools must disappear again
    await page.evaluate(() => (window as any).loadLevelKey("Level 02/01"));
    await expect(page.locator('[data-testid="tool-water"]')).toBeVisible();
    await expect(page.locator('[data-testid="tool-air"]')).toBeVisible();
    await expect(page.locator('[data-testid="tool-boat"]')).toHaveCount(0);
    await expect(page.locator('[data-testid="tool-maybeboat"]')).toHaveCount(0);
  });

  test('visual_test_mistake_counter_and_cell_blink', async ({ page }) => {
    // 1. Load Level 01/01
    await page.evaluate(() => (window as any).loadLevelKey("Level 01/01"));

    // Initial state: mistake counter should be 0
    const mistakeCounter = page.locator('[data-testid="mistake-counter"]');
    await expect(mistakeCounter).toBeVisible();
    const mistakeCount = page.locator('[data-testid="mistake-count"]');
    await expect(mistakeCount).toHaveText('0');
    const getMistakesVal = await page.evaluate(() => (window as any).getMistakes());
    expect(getMistakesVal).toBe(0);

    // In Level 01/01, row 0 is [Air, Water, Water]. Cell (0, 0) is Air in the solution!
    // Selecting water tool and clicking cell (0, 0) is a mistake!
    await page.click('[data-testid="tool-water"]');
    await page.click('[data-testid="cell-0-0"]');

    // Verify cell blinked red with authentic error overlay and data-error="true"
    const cell00 = page.locator('[data-testid="cell-0-0"]');
    await expect(cell00).toHaveAttribute('data-error', 'true');
    const errorOverlay = cell00.locator('[data-testid="cell-error"]');
    await expect(errorOverlay).toBeVisible();

    // Verify invalid content was NOT placed in the cell
    await expect(cell00).toHaveAttribute('data-content-left', 'none');

    // Verify mistake counter incremented to 1
    await expect(mistakeCount).toHaveText('1');
    const mistakesAfterOne = await page.evaluate(() => (window as any).getMistakes());
    expect(mistakesAfterOne).toBe(1);

    // 2. Pencil marks (Air / ✕) are never mistakes:
    // Right-click cell (0, 0) to place Air
    await page.click('[data-testid="cell-0-0"]', { button: 'right' });
    await expect(cell00).toHaveAttribute('data-content-left', 'air');
    // Mistakes should still be 1
    await expect(mistakeCount).toHaveText('1');

    // 3. Valid move (cell 0-1 is water in the solution):
    await page.click('[data-testid="cell-0-1"]');
    await expect(page.locator('[data-testid="cell-0-1"]')).toHaveAttribute('data-content-left', 'water');
    // Mistakes should still be 1
    await expect(mistakeCount).toHaveText('1');

    // 4. Click restart button: mistake counter must reset to 0
    await page.click('[data-testid="btn-restart"]');
    await expect(mistakeCount).toHaveText('0');
    const mistakesAfterRestart = await page.evaluate(() => (window as any).getMistakes());
    expect(mistakesAfterRestart).toBe(0);
  });

  test('visual_test_level_05_01_zero_water_aquarium_hint', async ({ page }) => {
    // Load Level 05/01 which has aquarium hints: {"0": 0, "2.5": 1, "3": 1}
    await page.evaluate(() => (window as any).loadLevelKey("Level 05/01"));

    // Aquarium section must be visible
    const aqSection = page.locator('[data-testid="aquarium-section"]');
    await expect(aqSection).toBeVisible();

    // 0-water aquarium hint must be visible
    const zeroAqHint = page.locator('[data-testid="aquarium-hint-0"]');
    await expect(zeroAqHint).toBeVisible();
    await expect(zeroAqHint.locator('.aq-tank-size')).toHaveText('0');
    // It should not render water texture inside the tank
    await expect(zeroAqHint.locator('.aq-tank-water')).toHaveCount(0);
    // Expected count should be ×0
    await expect(zeroAqHint.locator('.aq-expected-count')).toHaveText('×0');

    // The other aquarium hints must also be visible
    const aq25 = page.locator('[data-testid="aquarium-hint-2.5"]');
    await expect(aq25).toBeVisible();
    await expect(aq25.locator('.aq-tank-size')).toHaveText('2.5');
    await expect(aq25.locator('.aq-expected-count')).toHaveText('×1');

    const aq3 = page.locator('[data-testid="aquarium-hint-3"]');
    await expect(aq3).toBeVisible();
    await expect(aq3.locator('.aq-tank-size')).toHaveText('3');
    await expect(aq3.locator('.aq-expected-count')).toHaveText('×1');
  });

  test('visual_test_undo_redo_buttons_and_reactive_states', async ({ page }) => {
    // 1. Load Level 01/01
    await page.evaluate(() => (window as any).loadLevelKey("Level 01/01"));

    const btnUndo = page.locator('[data-testid="btn-undo"]');
    const btnRedo = page.locator('[data-testid="btn-redo"]');
    await expect(btnUndo).toBeVisible();
    await expect(btnRedo).toBeVisible();

    // Initial state: both should be disabled
    await expect(btnUndo).toBeDisabled();
    await expect(btnRedo).toBeDisabled();

    // Place air in cell (0, 0)
    await page.click('[data-testid="tool-air"]');
    await page.click('[data-testid="cell-0-0"]');
    await expect(page.locator('[data-testid="cell-0-0"]')).toHaveAttribute('data-content-left', 'air');

    // Undo is now enabled, Redo is still disabled
    await expect(btnUndo).toBeEnabled();
    await expect(btnRedo).toBeDisabled();

    // Click Undo
    await btnUndo.click();
    await expect(page.locator('[data-testid="cell-0-0"]')).toHaveAttribute('data-content-left', 'none');

    // Undo is now disabled, Redo is now enabled
    await expect(btnUndo).toBeDisabled();
    await expect(btnRedo).toBeEnabled();

    // Click Redo
    await btnRedo.click();
    await expect(page.locator('[data-testid="cell-0-0"]')).toHaveAttribute('data-content-left', 'air');

    // Undo is enabled, Redo is disabled
    await expect(btnUndo).toBeEnabled();
    await expect(btnRedo).toBeDisabled();
  });

  test('visual_test_undo_redo_keyboard_shortcuts', async ({ page }) => {
    // Load Level 01/01
    await page.evaluate(() => (window as any).loadLevelKey("Level 01/01"));

    const cell00 = page.locator('[data-testid="cell-0-0"]');

    // Place air in cell 0-0
    await page.click('[data-testid="tool-air"]');
    await page.click('[data-testid="cell-0-0"]');
    await expect(cell00).toHaveAttribute('data-content-left', 'air');

    // Test single-key 'z' for Undo
    await page.keyboard.press('z');
    await expect(cell00).toHaveAttribute('data-content-left', 'none');

    // Test single-key 'y' for Redo
    await page.keyboard.press('y');
    await expect(cell00).toHaveAttribute('data-content-left', 'air');

    // Test modifier key 'Control+z' for Undo
    await page.keyboard.press('Control+z');
    await expect(cell00).toHaveAttribute('data-content-left', 'none');

    // Test modifier key 'Control+y' for Redo
    await page.keyboard.press('Control+y');
    await expect(cell00).toHaveAttribute('data-content-left', 'air');
  });

  test('visual_test_undo_winning_move_restores_playable_state', async ({ page }) => {
    // Level 01/01 water cells: (0, 1), (0, 2), (1, 2), (2, 0), (2, 1), (2, 2)
    await page.evaluate(() => (window as any).loadLevelKey("Level 01/01"));
    await page.click('[data-testid="tool-water"]');

    // Place 5 of the 6 waters:
    await page.click('[data-testid="cell-0-1"]');
    await page.click('[data-testid="cell-0-2"]');
    await page.click('[data-testid="cell-1-2"]');
    await page.click('[data-testid="cell-2-0"]');
    await page.click('[data-testid="cell-2-1"]');

    const winBanner = page.locator('[data-testid="win-banner"]');
    await expect(winBanner).toHaveCount(0);

    // Place the 6th water cell to complete the puzzle:
    await page.click('[data-testid="cell-2-2"]');

    // Win banner appears!
    await expect(winBanner).toBeVisible();

    // Now press Undo
    await page.click('[data-testid="btn-undo"]');

    // Win banner must be dismissed, and (2, 2) is empty again!
    await expect(winBanner).toHaveCount(0);
    await expect(page.locator('[data-testid="cell-2-2"]')).toHaveAttribute('data-content-left', 'none');

    // Press Redo
    await page.click('[data-testid="btn-redo"]');

    // Win banner reappears!
    await expect(winBanner).toBeVisible();
    await expect(page.locator('[data-testid="cell-2-2"]')).toHaveAttribute('data-content-left', 'water');
  });

  test('visual_test_drag_stroke_undo_reverts_multiple_cells_in_one_step', async ({ page }) => {
    // Load Level 01/01
    await page.evaluate(() => (window as any).loadLevelKey("Level 01/01"));

    // Select Air tool
    await page.click('[data-testid="tool-air"]');

    // Drag from cell (0, 0) across to (1, 0) and (1, 1)
    const cell00 = page.locator('[data-testid="cell-0-0"]');
    const cell10 = page.locator('[data-testid="cell-1-0"]');
    const cell11 = page.locator('[data-testid="cell-1-1"]');

    const box00 = await cell00.boundingBox();
    const box10 = await cell10.boundingBox();
    const box11 = await cell11.boundingBox();

    if (box00 && box10 && box11) {
      await page.mouse.move(box00.x + box00.width / 2, box00.y + box00.height / 2);
      await page.mouse.down();
      await page.mouse.move(box10.x + box10.width / 2, box10.y + box10.height / 2);
      await page.mouse.move(box11.x + box11.width / 2, box11.y + box11.height / 2);
      await page.mouse.up();

      // All 3 cells should now have air
      await expect(cell00).toHaveAttribute('data-content-left', 'air');
      await expect(cell10).toHaveAttribute('data-content-left', 'air');
      await expect(cell11).toHaveAttribute('data-content-left', 'air');

      // Undo once with keyboard 'z'
      await page.keyboard.press('z');

      // All 3 cells reverted together!
      await expect(cell00).toHaveAttribute('data-content-left', 'none');
      await expect(cell10).toHaveAttribute('data-content-left', 'none');
      await expect(cell11).toHaveAttribute('data-content-left', 'none');

      // Redo once with keyboard 'y'
      await page.keyboard.press('y');

      // All 3 cells restored together!
      await expect(cell00).toHaveAttribute('data-content-left', 'air');
      await expect(cell10).toHaveAttribute('data-content-left', 'air');
      await expect(cell11).toHaveAttribute('data-content-left', 'air');
    }
  });

});



