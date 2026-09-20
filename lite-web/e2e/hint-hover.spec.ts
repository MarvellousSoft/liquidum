import { test, expect } from '@playwright/test';

test.describe('Hint Hover Text and Line Highlighting', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/?mode=test');
    await expect(page.locator('.grid-board-card')).toBeVisible();
    await expect(page.locator('[data-testid="tool-water"]')).toBeVisible();
  });

  test('displays custom hover text (title) on row and column hints', async ({ page }) => {
    // Level 01/01 has:
    // row hints: row 0 -> 2, row 1 -> 1, row 2 -> 3
    // col hints: col 0 -> 1, col 1 -> 2, col 2 -> 3
    const row0 = page.locator('[data-testid="row-hint-0"]');
    const row1 = page.locator('[data-testid="row-hint-1"]');
    const col0 = page.locator('[data-testid="col-hint-0"]');
    const col1 = page.locator('[data-testid="col-hint-1"]');

    await expect(row0).toHaveAttribute('title', 'There are 2 water cells in this row.');
    await expect(row1).toHaveAttribute('title', 'There is 1 water cell in this row.');
    await expect(col0).toHaveAttribute('title', 'There is 1 water cell in this column.');
    await expect(col1).toHaveAttribute('title', 'There are 2 water cells in this column.');
  });

  test('hovering on a row hint highlights just that row', async ({ page }) => {
    const row1Hint = page.locator('[data-testid="row-hint-1"]');
    await row1Hint.hover();

    // The row hint itself gets hint-hovered class
    await expect(row1Hint).toHaveClass(/hint-hovered/);

    // All cells in row 1 must have cell-hovered-line
    const cell10 = page.locator('[data-testid="cell-1-0"]');
    const cell11 = page.locator('[data-testid="cell-1-1"]');
    const cell12 = page.locator('[data-testid="cell-1-2"]');
    await expect(cell10).toHaveClass(/cell-hovered-line/);
    await expect(cell11).toHaveClass(/cell-hovered-line/);
    await expect(cell12).toHaveClass(/cell-hovered-line/);

    // Cells outside row 1 must NOT have cell-hovered-line
    const cell00 = page.locator('[data-testid="cell-0-0"]');
    const cell22 = page.locator('[data-testid="cell-2-2"]');
    await expect(cell00).not.toHaveClass(/cell-hovered-line/);
    await expect(cell22).not.toHaveClass(/cell-hovered-line/);

    // Col hints must not be highlighted
    const col0Hint = page.locator('[data-testid="col-hint-0"]');
    await expect(col0Hint).not.toHaveClass(/hint-hovered/);
  });

  test('hovering on a column hint highlights just that column', async ({ page }) => {
    const col2Hint = page.locator('[data-testid="col-hint-2"]');
    await col2Hint.hover();

    // The column hint itself gets hint-hovered class
    await expect(col2Hint).toHaveClass(/hint-hovered/);

    // All cells in col 2 must have cell-hovered-line
    const cell02 = page.locator('[data-testid="cell-0-2"]');
    const cell12 = page.locator('[data-testid="cell-1-2"]');
    const cell22 = page.locator('[data-testid="cell-2-2"]');
    await expect(cell02).toHaveClass(/cell-hovered-line/);
    await expect(cell12).toHaveClass(/cell-hovered-line/);
    await expect(cell22).toHaveClass(/cell-hovered-line/);

    // Cells outside col 2 must NOT have cell-hovered-line
    const cell00 = page.locator('[data-testid="cell-0-0"]');
    const cell11 = page.locator('[data-testid="cell-1-1"]');
    await expect(cell00).not.toHaveClass(/cell-hovered-line/);
    await expect(cell11).not.toHaveClass(/cell-hovered-line/);

    // Row hints must not be highlighted
    const row0Hint = page.locator('[data-testid="row-hint-0"]');
    await expect(row0Hint).not.toHaveClass(/hint-hovered/);
  });

  test('hovering on boat and special hints displays expected text', async ({ page }) => {
    // Load Level 04/06 which has boat hints
    await page.evaluate(() => {
      (window as any).loadLevelKey?.('Level 04/06');
    });
    await page.waitForTimeout(300);

    // Row 1 has 2 boats ("There are 2 boats in this row.")
    // Col 0 has 1 boat ("There is 1 boat in this column.")
    // Col 4 has 0 boats ("There are no boats in this column.")
    const row1BoatSpan = page.locator('[data-testid="row-hint-1"] span[title*="boat"]');
    const col0BoatSpan = page.locator('[data-testid="col-hint-0"] span[title*="boat"]');
    const col4BoatSpan = page.locator('[data-testid="col-hint-4"] span[title*="boat"]');

    await expect(row1BoatSpan).toHaveAttribute('title', 'There are 2 boats in this row.');
    await expect(col0BoatSpan).toHaveAttribute('title', 'There is 1 boat in this column.');
    await expect(col4BoatSpan).toHaveAttribute('title', 'There are no boats in this column.');
  });

  test('boat hints and water hints are center-aligned within their slots with distinct spacing', async ({ page }) => {
    // Load Level 06/03 which has dual row hints across rows
    await page.evaluate(() => {
      (window as any).loadLevelKey?.('Level 06/03');
    });
    await page.waitForTimeout(300);

    const row0BoatSlot = page.locator('[data-testid="row-hint-0"] .row-hint-boat-slot');
    const row0WaterSlot = page.locator('[data-testid="row-hint-0"] .row-hint-water-slot');
    const row0BoatImg = page.locator('[data-testid="row-hint-0"] .hint-boat-icon');
    const row1BoatImg = page.locator('[data-testid="row-hint-1"] .hint-boat-icon');

    await expect(row0BoatImg).toBeVisible();
    await expect(row1BoatImg).toBeVisible();

    // Both slots are center-aligned
    const boatSlotJustify = await row0BoatSlot.evaluate(el => window.getComputedStyle(el).justifyContent);
    const waterSlotJustify = await row0WaterSlot.evaluate(el => window.getComputedStyle(el).justifyContent);
    expect(boatSlotJustify).toBe('center');
    expect(waterSlotJustify).toBe('center');

    // Space between boat slot and water slot is at least 10px
    const boxBoatSlot = await row0BoatSlot.boundingBox();
    const boxWaterSlot = await row0WaterSlot.boundingBox();
    expect(boxBoatSlot).not.toBeNull();
    expect(boxWaterSlot).not.toBeNull();
    const space = boxWaterSlot!.x - (boxBoatSlot!.x + boxBoatSlot!.width);
    expect(space).toBeGreaterThanOrEqual(10);
  });

  test('hints and hoverable elements have cursor: help and user-select: none', async ({ page }) => {
    const row0 = page.locator('[data-testid="row-hint-0"]');
    const col0 = page.locator('[data-testid="col-hint-0"]');
    const cornerSpacer = page.locator('.grid-corner-spacer').first();

    // Hoverable hints must have cursor: help and user-select: none
    const row0Cursor = await row0.evaluate((el) => window.getComputedStyle(el).cursor);
    const row0UserSelect = await row0.evaluate((el) => window.getComputedStyle(el).userSelect);
    expect(row0Cursor).toBe('help');
    expect(row0UserSelect).toBe('none');

    const col0Cursor = await col0.evaluate((el) => window.getComputedStyle(el).cursor);
    const col0UserSelect = await col0.evaluate((el) => window.getComputedStyle(el).userSelect);
    expect(col0Cursor).toBe('help');
    expect(col0UserSelect).toBe('none');

    // Spacers without title must have cursor: default and user-select: none
    const spacerCursor = await cornerSpacer.evaluate((el) => window.getComputedStyle(el).cursor);
    const spacerUserSelect = await cornerSpacer.evaluate((el) => window.getComputedStyle(el).userSelect);
    expect(spacerCursor).toBe('default');
    expect(spacerUserSelect).toBe('none');

    // Stats counter with title has cursor: help
    const waterCounter = page.locator('[data-testid="hint-water-counter"]');
    if (await waterCounter.isVisible()) {
      const counterCursor = await waterCounter.evaluate((el) => window.getComputedStyle(el).cursor);
      expect(counterCursor).toBe('help');
    }
  });
});
