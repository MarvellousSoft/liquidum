import { test, expect } from '@playwright/test';

test.describe('Daily Level E2E Tests', () => {

  test.beforeEach(async ({ context }) => {
    await context.grantPermissions(['clipboard-read', 'clipboard-write']);
  });

  test('loads daily level by default when visiting root url without appending date', async ({ page }) => {
    await page.goto('/');

    // Daily banner should be visible
    await expect(page.locator('[data-testid="daily-banner"]')).toBeVisible();
    await expect(page.locator('[data-testid="btn-daily-mode"]')).toHaveClass(/level-btn-daily-active/);

    // No next/prev buttons should exist
    await expect(page.locator('[data-testid="btn-prev-day"]')).toHaveCount(0);
    await expect(page.locator('[data-testid="btn-next-day"]')).toHaveCount(0);
    await expect(page.locator('[data-testid="daily-date-picker"]')).toHaveCount(0);

    // Root URL should remain clean without auto-appending '?daily=...'
    expect(page.url()).not.toContain('daily=');

    // Time left and streak should be visible in start overlay and top bar
    await expect(page.locator('[data-testid="daily-time-left"]')).toBeVisible();
    await expect(page.locator('[data-testid="daily-streak-display"]')).toBeVisible();
    await expect(page.locator('[data-testid="daily-streak-badge"]')).toBeVisible();
  });

  test('loads daily level via URL param ?daily=2024-01-07 for past date', async ({ page }) => {
    await page.goto('/?daily=2024-01-07');

    // Daily banner should be visible
    await expect(page.locator('[data-testid="daily-banner"]')).toBeVisible();

    // Weekday info should show Sunday / Aquarium Sunday
    const dailyInfo = page.locator('[data-testid="daily-info"]');
    await expect(dailyInfo).toContainText('Aquarium Sunday');
    await expect(dailyInfo).toContainText('2024-01-07');
    await expect(dailyInfo).toContainText('🐟');

    // Daily button in level picker should have active style
    const dailyBtn = page.locator('[data-testid="btn-daily-mode"]');
    await expect(dailyBtn).toHaveClass(/level-btn-daily-active/);

    // Grid cells should be rendered
    await expect(page.locator('[data-testid="cell-0-0"]')).toBeVisible();
  });

  test('disallows future dates via URL and clamps to today', async ({ page }) => {
    await page.goto('/?daily=2099-01-01');

    await expect(page.locator('[data-testid="daily-banner"]')).toBeVisible();

    // Info should NOT show 2099
    const dailyInfo = page.locator('[data-testid="daily-info"]');
    await expect(dailyInfo).not.toContainText('2099');

    // URL should not retain the future date
    expect(page.url()).not.toContain('2099-01-01');
  });

  test('fixed levels are hidden in popup modal and can be selected', async ({ page }) => {
    await page.goto('/');

    // Fixed level buttons should not be in the main page
    await expect(page.locator('button:has-text("Level 01/01")')).toHaveCount(0);
    await expect(page.locator('[data-testid="levels-modal"]')).toHaveCount(0);

    // Open levels modal
    await page.click('[data-testid="btn-open-levels-modal"]');
    await expect(page.locator('[data-testid="levels-modal"]')).toBeVisible();

    // Select Level 01/01
    await page.click('[data-testid="levels-modal"] button:has-text("Level 01/01")');

    // Modal closes and Level 01/01 is active
    await expect(page.locator('[data-testid="levels-modal"]')).toHaveCount(0);
    await expect(page.locator('[data-testid="daily-banner"]')).toHaveCount(0);
    await expect(page.locator('[data-testid="btn-daily-mode"]')).not.toHaveClass(/level-btn-daily-active/);
    await expect(page.locator('[data-testid="btn-open-levels-modal"]')).toContainText('Level 01/01');

    // Switch back to Daily Level
    await page.click('[data-testid="btn-daily-mode"]');
    await expect(page.locator('[data-testid="daily-banner"]')).toBeVisible();
    await expect(page.locator('[data-testid="btn-daily-mode"]')).toHaveClass(/level-btn-daily-active/);
  });

  test('hides restart button on daily levels and ignores R shortcut', async ({ page }) => {
    await page.goto('/?daily=2024-01-07');
    await expect(page.locator('[data-testid="cell-0-0"]')).toBeVisible();

    // Start puzzle overlay should be visible
    await expect(page.locator('[data-testid="start-puzzle-overlay"]')).toBeVisible();
    await page.click('[data-testid="btn-start-puzzle"]');
    await expect(page.locator('[data-testid="start-puzzle-overlay"]')).toHaveCount(0);

    // Restart button should NOT be visible on daily level
    await expect(page.locator('[data-testid="btn-restart"]')).toHaveCount(0);

    // Place air on cell 0-0
    await page.click('[data-testid="tool-air"]');
    await page.click('[data-testid="cell-0-0"]');
    await expect(page.locator('[data-testid="cell-0-0"]')).toHaveAttribute('data-content-left', 'air');

    // Press 'r' shortcut: should be ignored on daily level
    await page.keyboard.press('r');

    // Cell should NOT be reset
    await expect(page.locator('[data-testid="cell-0-0"]')).toHaveAttribute('data-content-left', 'air');
    await expect(page.locator('[data-testid="daily-banner"]')).toBeVisible();
  });

  test('persists level progress and timer across reloads using UserLevelSaveData', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('[data-testid="btn-start-puzzle"]')).toBeVisible();

    // Click start puzzle
    await page.click('[data-testid="btn-start-puzzle"]');
    await expect(page.locator('[data-testid="start-puzzle-overlay"]')).toHaveCount(0);

    // Place air on cell 0-0
    await page.click('[data-testid="tool-air"]');
    await page.click('[data-testid="cell-0-0"]');
    await expect(page.locator('[data-testid="cell-0-0"]')).toHaveAttribute('data-content-left', 'air');

    // Wait for at least 1 second for timer to advance and auto-save
    await page.waitForTimeout(1200);

    // Reload the page
    await page.reload();

    // After reload, start overlay should NOT be present (already started)
    await expect(page.locator('[data-testid="start-puzzle-overlay"]')).toHaveCount(0);

    // Cell content should be restored from localStorage
    await expect(page.locator('[data-testid="cell-0-0"]')).toHaveAttribute('data-content-left', 'air');

    // Timer should be greater than 0
    const timeSecs = await page.evaluate(() => (window as any).getTime());
    expect(timeSecs).toBeGreaterThanOrEqual(1);
  });

  test('discards yesterday daily progress when loading today', async ({ page }) => {
    // Inject yesterday's progress into localStorage
    await page.goto('/');
    await page.evaluate(() => {
      const yesterdaySave = {
        date: '2024-01-01',
        save_data: {
          version: 1,
          grid_data: {},
          is_empty: false,
          mistakes: 3,
          timer_secs: 55.0,
          best_mistakes: -1,
          best_time_secs: -1.0,
        },
      };
      localStorage.setItem('liquidum_daily_level_save', JSON.stringify(yesterdaySave));
    });

    // Reload page (loads today's puzzle)
    await page.reload();

    // Start overlay should be visible because yesterday's save was discarded
    await expect(page.locator('[data-testid="start-puzzle-overlay"]')).toBeVisible();

    // Storage should no longer contain yesterday's date
    const stored = await page.evaluate(() => localStorage.getItem('liquidum_daily_level_save'));
    if (stored) {
      const parsed = JSON.parse(stored);
      expect(parsed.date).not.toBe('2024-01-01');
    }
  });

  test('loads test levels via URL query parameters and shows restart button without leaderboard', async ({ page }) => {
    await page.goto('/?level=01/01');

    // Should load test level 01/01
    await expect(page.locator('[data-testid="btn-open-levels-modal"]')).toContainText('Level 01/01');
    await expect(page.locator('[data-testid="daily-banner"]')).toHaveCount(0);

    // On test levels, leaderboard button should be removed
    await expect(page.locator('[data-testid="btn-leaderboard"]')).toHaveCount(0);

    // Restart button should be visible on test levels
    await expect(page.locator('[data-testid="btn-restart"]')).toBeVisible();

    // Place air on cell 0-0
    await page.click('[data-testid="tool-air"]');
    await page.click('[data-testid="cell-0-0"]');
    await expect(page.locator('[data-testid="cell-0-0"]')).toHaveAttribute('data-content-left', 'air');

    // Click restart button
    await page.click('[data-testid="btn-restart"]');
    await expect(page.locator('[data-testid="cell-0-0"]')).toHaveAttribute('data-content-left', 'none');

    // Test another section level via URL
    await page.goto('/?level=04/05');
    await expect(page.locator('[data-testid="btn-open-levels-modal"]')).toContainText('Level 04/05');
    // Boat tool should be visible for section 04
    await expect(page.locator('[data-testid="tool-boat"]')).toBeVisible();
  });

  test('completes daily level and displays win banner without next day or play again button', async ({ page }) => {
    // Mock any PlayFab calls to ensure zero production requests
    await page.route('**/*playfabapi.com/**', (route) => {
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ code: 200, status: 'OK', data: {} }),
      });
    });

    await page.goto('/?daily=2024-01-07');
    await expect(page.locator('[data-testid="cell-0-0"]')).toBeVisible();

    // Click start puzzle
    await page.click('[data-testid="btn-start-puzzle"]');

    // Solve the daily level using solution cells
    await page.evaluate(() => {
      const g = (window as any).getGridData();
      if (!g || !g.solution_c_left) return;
      for (let r = 0; r < g.cells.length; r++) {
        for (let c = 0; c < g.cells[r].length; c++) {
          const cell = g.cells[r][c];
          const solL = g.solution_c_left[r][c];
          const solR = g.solution_c_right[r][c];
          // DecDiag (10) uses BottomLeft (8), IncDiag (9) / Single (11) use TopLeft (5)
          const leftCorner = cell.type === 10 ? 8 : 5;
          // IncDiag (9) uses BottomRight (7), DecDiag (10) / Single (11) use TopRight (6)
          const rightCorner = cell.type === 9 ? 7 : 6;
          if (solL === 1 || solL === 2) {
            (window as any).putCellAction(r, c, leftCorner, solL);
          }
          if (solR === 1 || solR === 2) {
            (window as any).putCellAction(r, c, rightCorner, solR);
          }
        }
      }
    });

    // Win banner should appear
    await expect(page.locator('[data-testid="win-banner"]')).toBeVisible();
    await expect(page.locator('[data-testid="win-banner"]')).toContainText('Daily Complete');
    await expect(page.locator('[data-testid="win-time"]')).toBeVisible();
    await expect(page.locator('[data-testid="win-streak"]')).toBeVisible();
    await expect(page.locator('[data-testid="btn-share-result"]')).toBeVisible();
    await expect(page.locator('[data-testid="btn-leaderboard-win"]')).toBeVisible();

    // Next Day button and Play Again button should NOT exist in daily mode
    await expect(page.locator('[data-testid="btn-next-day-win"]')).toHaveCount(0);
    await expect(page.locator('[data-testid="btn-play-again"]')).toHaveCount(0);

    // Steam promo text and link should be visible and link to Steam store
    const steamPromoText = page.locator('[data-testid="steam-promo-text"]');
    await expect(steamPromoText).toBeVisible();
    await expect(steamPromoText).toContainText('Want More? Download liquidum on Steam');

    const steamLink = page.locator('[data-testid="btn-steam-link"]');
    await expect(steamLink).toBeVisible();
    await expect(steamLink).toHaveAttribute('href', 'https://store.steampowered.com/app/2690070/Liquidum/');

    // Click Share Result and verify clipboard contents
    await page.click('[data-testid="btn-share-result"]');
    await expect(page.locator('[data-testid="btn-share-result"]')).toContainText('Copied');

    const clipboardText = await page.evaluate(() => navigator.clipboard.readText());
    expect(clipboardText).toContain('I won #liquidum daily on 2024-01-07');
    expect(clipboardText).toContain('🐟 Aquarium Sunday');
    expect(clipboardText).toContain('🏆 0 mistakes');
    expect(clipboardText).toContain('linktr.ee/liquidum');
  });

  test('verifies page layout order: logo, selector, daily description, tools, grid, and NxM size string', async ({ page }) => {
    await page.goto('/?daily=2024-01-07');

    const logo = page.locator('.game-title');
    const selector = page.locator('.level-picker');
    const description = page.locator('[data-testid="daily-banner"]');
    const tools = page.locator('.controls-toolbar');
    const gridHints = page.locator('[data-testid="grid-hints-card"]');
    const sizeLabel = page.locator('[data-testid="grid-size-label"]');

    await expect(logo).toBeVisible();
    await expect(selector).toBeVisible();
    await expect(description).toBeVisible();
    await expect(tools).toBeVisible();
    await expect(gridHints).toBeVisible();
    await expect(sizeLabel).toBeVisible();

    // Verify NxM string format (e.g. 6x6)
    await expect(sizeLabel).toHaveText(/^\d+x\d+$/);
    const sizeText = await sizeLabel.textContent();
    expect(sizeText).toBe('5x4');

    // Verify vertical layout ordering: Logo -> Selector -> Description -> Tools -> Grid
    const logoBox = await logo.boundingBox();
    const selectorBox = await selector.boundingBox();
    const descBox = await description.boundingBox();
    const toolsBox = await tools.boundingBox();
    const gridBox = await gridHints.boundingBox();
    const sizeBox = await sizeLabel.boundingBox();

    expect(logoBox!.y).toBeLessThan(selectorBox!.y);
    expect(selectorBox!.y).toBeLessThan(descBox!.y);
    expect(descBox!.y).toBeLessThan(toolsBox!.y);
    expect(toolsBox!.y).toBeLessThan(gridBox!.y);

    // Size label should be at bottom of grid
    expect(sizeBox!.y).toBeGreaterThan(gridBox!.y);
  });

});
