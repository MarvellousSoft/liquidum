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

  test('restarts daily level with R key and button', async ({ page }) => {
    await page.goto('/?daily=2024-01-07');
    await expect(page.locator('[data-testid="cell-0-0"]')).toBeVisible();

    // Start puzzle overlay should be visible
    await expect(page.locator('[data-testid="start-puzzle-overlay"]')).toBeVisible();
    await page.click('[data-testid="btn-start-puzzle"]');
    await expect(page.locator('[data-testid="start-puzzle-overlay"]')).toHaveCount(0);

    // Place air on cell 0-0
    await page.click('[data-testid="tool-air"]');
    await page.click('[data-testid="cell-0-0"]');
    await expect(page.locator('[data-testid="cell-0-0"]')).toHaveAttribute('data-content-left', 'air');

    // Press 'r' shortcut to restart
    await page.keyboard.press('r');

    // Cell should be reset to none
    await expect(page.locator('[data-testid="cell-0-0"]')).toHaveAttribute('data-content-left', 'none');
    // Should still be in daily mode
    await expect(page.locator('[data-testid="daily-banner"]')).toBeVisible();
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

});
