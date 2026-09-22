import { test, expect } from '@playwright/test';

test.describe('Hint Dimming QoL Feature (Right-Click Toggle)', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/?mode=test');
    await expect(page.locator('.grid-board-card')).toBeVisible();
    await expect(page.locator('[data-testid="tool-water"]')).toBeVisible();
  });

  test('right-clicking a row hint toggles dimmed state', async ({ page }) => {
    const rowHint0 = page.locator('[data-testid="row-hint-0"]');

    // Initially not dimmed
    await expect(rowHint0).not.toHaveClass(/hint-dimmed/);
    await expect(rowHint0).toHaveAttribute('data-dimmed', 'false');

    // Right click row hint 0
    await rowHint0.click({ button: 'right' });

    // Should now be dimmed
    await expect(rowHint0).toHaveClass(/hint-dimmed/);
    await expect(rowHint0).toHaveAttribute('data-dimmed', 'true');

    // Move mouse away and wait for transition (transition: opacity 0.2s)
    await page.mouse.move(0, 0);
    await page.waitForTimeout(250);

    const opacityDimmed = await rowHint0.evaluate(el => parseFloat(window.getComputedStyle(el).opacity));
    expect(opacityDimmed).toBeCloseTo(0.35, 1);

    // Right click again to un-dim
    await rowHint0.click({ button: 'right' });

    // Should no longer be dimmed
    await expect(rowHint0).not.toHaveClass(/hint-dimmed/);
    await expect(rowHint0).toHaveAttribute('data-dimmed', 'false');

    const opacityNormal = await rowHint0.evaluate(el => parseFloat(window.getComputedStyle(el).opacity));
    expect(opacityNormal).toBeCloseTo(1, 1);
  });

  test('right-clicking a column hint toggles dimmed state', async ({ page }) => {
    const colHint1 = page.locator('[data-testid="col-hint-1"]');

    await expect(colHint1).not.toHaveClass(/hint-dimmed/);
    await expect(colHint1).toHaveAttribute('data-dimmed', 'false');

    // Right click column hint 1
    await colHint1.click({ button: 'right' });

    await expect(colHint1).toHaveClass(/hint-dimmed/);
    await expect(colHint1).toHaveAttribute('data-dimmed', 'true');

    // Right click again to un-dim
    await colHint1.click({ button: 'right' });

    await expect(colHint1).not.toHaveClass(/hint-dimmed/);
    await expect(colHint1).toHaveAttribute('data-dimmed', 'false');
  });

  test('restarting the level clears dimmed hints', async ({ page }) => {
    const rowHint0 = page.locator('[data-testid="row-hint-0"]');
    const colHint0 = page.locator('[data-testid="col-hint-0"]');

    await rowHint0.click({ button: 'right' });
    await colHint0.click({ button: 'right' });

    await expect(rowHint0).toHaveClass(/hint-dimmed/);
    await expect(colHint0).toHaveClass(/hint-dimmed/);

    // Click restart button
    const restartBtn = page.locator('button[title*="Restart"], button[aria-label*="Restart"], button:has-text("Restart")');
    if (await restartBtn.count() > 0) {
      await restartBtn.first().click();
    } else {
      // Trigger via hotkey 'r'
      await page.keyboard.press('r');
    }
    await page.waitForTimeout(300);

    // Dimmed state should have reset
    await expect(rowHint0).not.toHaveClass(/hint-dimmed/);
    await expect(colHint0).not.toHaveClass(/hint-dimmed/);
    await expect(rowHint0).toHaveAttribute('data-dimmed', 'false');
    await expect(colHint0).toHaveAttribute('data-dimmed', 'false');
  });

  test('dual hint levels support slot-specific dimming', async ({ page }) => {
    // Load Level 06/03 which has dual row hints
    await page.evaluate(() => {
      (window as any).loadLevelKey?.('Level 06/03');
    });
    await page.waitForTimeout(300);

    const row0 = page.locator('[data-testid="row-hint-0"]');
    const boatSlot = row0.locator('.row-hint-boat-slot');
    const waterSlot = row0.locator('.row-hint-water-slot');

    await expect(boatSlot).toBeVisible();
    await expect(waterSlot).toBeVisible();

    // Right click specifically on the boat slot
    await boatSlot.click({ button: 'right' });

    // Boat slot should be dimmed, but water slot should NOT be dimmed
    await expect(boatSlot).toHaveClass(/hint-dimmed/);
    await expect(boatSlot).toHaveAttribute('data-dimmed', 'true');
    await expect(waterSlot).not.toHaveClass(/hint-dimmed/);
    await expect(waterSlot).toHaveAttribute('data-dimmed', 'false');

    // Right click specifically on water slot
    await waterSlot.click({ button: 'right' });

    // Both are now dimmed, so row0 is dimmed
    await expect(waterSlot).toHaveClass(/hint-dimmed/);
    await expect(row0).toHaveClass(/hint-dimmed/);

    // Right click boat slot again to un-dim boat
    await boatSlot.click({ button: 'right' });
    await expect(boatSlot).not.toHaveClass(/hint-dimmed/);
    await expect(waterSlot).toHaveClass(/hint-dimmed/);
    await expect(row0).not.toHaveClass(/hint-dimmed/);
  });

  test('opposite hints reflect dimmed state and can also toggle it', async ({ page }) => {
    // Enable opposite hints via settings
    await page.evaluate(() => {
      const s = JSON.parse(localStorage.getItem('liquidum_settings') || '{}');
      s.line_info = 'missing';
      localStorage.setItem('liquidum_settings', JSON.stringify(s));
    });
    await page.reload();
    await expect(page.locator('.grid-board-card')).toBeVisible();

    const row0 = page.locator('[data-testid="row-hint-0"]');
    const row0Opposite = page.locator('[data-testid="row-hint-opposite-0"]');
    await expect(row0Opposite).toBeVisible();

    // Right-click left row hint 0 -> opposite row hint dims too
    await row0.click({ button: 'right' });
    await expect(row0).toHaveClass(/hint-dimmed/);
    await expect(row0Opposite).toHaveClass(/hint-dimmed/);

    // Right-click opposite row hint -> un-dims both
    await row0Opposite.click({ button: 'right' });
    await expect(row0).not.toHaveClass(/hint-dimmed/);
    await expect(row0Opposite).not.toHaveClass(/hint-dimmed/);
  });

  test('solving puzzle works normally when hints are dimmed', async ({ page }) => {
    // Dim all row hints
    await page.locator('[data-testid="row-hint-0"]').click({ button: 'right' });
    await page.locator('[data-testid="row-hint-1"]').click({ button: 'right' });
    await page.locator('[data-testid="row-hint-2"]').click({ button: 'right' });

    // Ensure test mode Level 01/01
    await page.evaluate(() => (window as any).loadLevelKey("Level 01/01"));

    // Mark air in non-water cells
    await page.click('[data-testid="cell-0-0"]', { button: 'right' });
    await page.click('[data-testid="cell-1-0"]', { button: 'right' });
    await page.click('[data-testid="cell-1-1"]', { button: 'right' });

    // Select water tool
    await page.click('[data-testid="tool-water"]');

    // Fill water cells
    await page.click('[data-testid="cell-0-1"]');
    await page.click('[data-testid="cell-0-2"]');
    await page.click('[data-testid="cell-1-2"]');
    await page.click('[data-testid="cell-2-0"]');
    await page.click('[data-testid="cell-2-1"]');
    await page.click('[data-testid="cell-2-2"]');

    // Check victory
    await expect(page.locator('[data-testid="win-banner"]')).toBeVisible();
  });
});
