import { test, expect } from '@playwright/test';

test.describe('Tutorial Grids Visual Snapshots', () => {
  test('matches visual snapshots for all tutorial grids', async ({ page }) => {
    // Open in test mode to bypass welcome modals, then open Help Modal
    await page.goto('/?mode=test');
    await page.locator('[data-testid="btn-help"]').click({ force: true });
    await expect(page.locator('[data-testid="help-modal"]')).toBeVisible();

    // Wait a bit for rendering to stabilize
    await page.waitForTimeout(500);

    // Get all tutorial grids by their test IDs
    // Since test IDs are dynamic (e.g., tutorial-grid-valid), we can select by a common class or regex,
    // or just find all elements that have a data-testid starting with tutorial-grid-
    const grids = page.locator('[data-testid^="tutorial-grid-"]');
    const count = await grids.count();

    expect(count).toBeGreaterThan(0);

    for (let i = 0; i < count; i++) {
      const grid = grids.nth(i);
      // Wait for it to be fully visible
      await expect(grid).toBeVisible();
      // Take snapshot of this specific element
      await expect(grid).toHaveScreenshot(`tutorial-grid-${i}.png`, { maxDiffPixels: 2 });
    }
  });
});
