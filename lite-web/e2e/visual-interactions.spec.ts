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

    // Tools and grid are visible
    await expect(page.locator('[data-testid="tool-water"]')).toBeVisible();
    await expect(page.locator('[data-testid="tool-boat"]')).toBeVisible();
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
    // 2x2 grid with walls below row 1
    const gridWithWalls = `
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

});
