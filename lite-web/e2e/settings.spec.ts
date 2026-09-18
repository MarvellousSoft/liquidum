import { test, expect } from '@playwright/test';

test.describe('Settings Modal & Features E2E', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/?mode=test');
    await page.waitForSelector('[data-testid="cell-0-0"]');
  });

  test('opens and closes settings modal with all sections present', async ({ page }) => {
    const settingsBtn = page.locator('[data-testid="btn-settings"]');
    await expect(settingsBtn).toBeVisible();
    await settingsBtn.click();

    const modal = page.locator('[data-testid="settings-modal"]');
    await expect(modal).toBeVisible();

    // Verify sections
    await expect(modal).toContainText('Display');
    await expect(modal).toContainText('Gameplay');
    await expect(modal).toContainText('Accessibility');
    await expect(modal).toContainText('Controls');

    // Verify specific settings
    await expect(page.locator('[data-testid="setting-dark-mode"]')).toBeVisible();
    await expect(page.locator('[data-testid="setting-show-bubbles"]')).toBeVisible();
    await expect(page.locator('[data-testid="setting-line-info"]')).toBeVisible();
    await expect(page.locator('[data-testid="setting-highlight-hints"]')).toBeVisible();
    await expect(page.locator('[data-testid="setting-highlight-grid"]')).toBeVisible();
    await expect(page.locator('[data-testid="setting-show-preview"]')).toBeVisible();
    await expect(page.locator('[data-testid="setting-hide-unknown"]')).toBeVisible();
    await expect(page.locator('[data-testid="setting-progress-unknown"]')).toBeVisible();
    await expect(page.locator('[data-testid="setting-show-timer"]')).toBeVisible();
    await expect(page.locator('[data-testid="setting-skip-anims"]')).toBeVisible();
    await expect(page.locator('[data-testid="setting-bigger-hints"]')).toBeVisible();
    await expect(page.locator('[data-testid="setting-thicker-walls"]')).toBeVisible();
    await expect(page.locator('[data-testid="setting-drag-content"]')).toBeVisible();
    await expect(page.locator('[data-testid="setting-invert-mouse"]')).toBeVisible();
    await expect(page.locator('[data-testid="auto-flood-air"]')).toBeVisible();

    // Close modal
    await page.locator('[data-testid="btn-close-settings"]').click();
    await expect(modal).toHaveCount(0);
  });

  test('toggles display and accessibility options with correct class application', async ({ page }) => {
    await page.locator('[data-testid="btn-settings"]').click();

    const container = page.locator('.game-container');

    // Bigger hints
    const biggerHintsCheckbox = page.locator('[data-testid="setting-bigger-hints"]');
    await biggerHintsCheckbox.check();
    await expect(container).toHaveClass(/bigger-hints/);

    // Thicker walls
    const thickerWallsCheckbox = page.locator('[data-testid="setting-thicker-walls"]');
    await thickerWallsCheckbox.check();
    await expect(container).toHaveClass(/thicker-walls/);

    // Show bubbles (off -> no-bubbles)
    const bubblesCheckbox = page.locator('[data-testid="setting-show-bubbles"]');
    await bubblesCheckbox.uncheck();
    await expect(container).toHaveClass(/no-bubbles/);

    // Skip animations
    const skipAnimsCheckbox = page.locator('[data-testid="setting-skip-anims"]');
    await skipAnimsCheckbox.check();
    await expect(container).toHaveClass(/skip-animations/);
  });

  test('displays incomplete line info on opposite side when configured', async ({ page }) => {
    // Initially line_info is 'none', opposite hints should not exist
    await expect(page.locator('[data-testid="row-hint-opposite-0"]')).toHaveCount(0);
    await expect(page.locator('[data-testid="col-hint-opposite-0"]')).toHaveCount(0);

    // Open settings and select 'missing'
    await page.locator('[data-testid="btn-settings"]').click();
    const lineInfoSelect = page.locator('[data-testid="setting-line-info"]');
    await lineInfoSelect.selectOption('missing');
    await page.locator('[data-testid="btn-close-settings"]').click();

    // Opposite hints should now be visible
    const rowOpposite0 = page.locator('[data-testid="row-hint-opposite-0"]');
    const colOpposite0 = page.locator('[data-testid="col-hint-opposite-0"]');
    await expect(rowOpposite0).toBeVisible();
    await expect(colOpposite0).toBeVisible();

    // Switch to 'current'
    await page.locator('[data-testid="btn-settings"]').click();
    await lineInfoSelect.selectOption('current');
    await page.locator('[data-testid="btn-close-settings"]').click();
    await expect(rowOpposite0).toBeVisible();

    // Switch back to 'none'
    await page.locator('[data-testid="btn-settings"]').click();
    await lineInfoSelect.selectOption('none');
    await page.locator('[data-testid="btn-close-settings"]').click();
    await expect(page.locator('[data-testid="row-hint-opposite-0"]')).toHaveCount(0);
  });

  test('inverts mouse clicks when invert_mouse setting is active', async ({ page }) => {
    // By default left click on empty cell-0-1 places water
    const cell = page.locator('[data-testid="cell-0-1"]');
    await cell.click({ button: 'left' });
    await expect(cell).toHaveAttribute('data-content-left', 'water');

    // Revert cell to empty
    await cell.click({ button: 'left' });
    await expect(cell).toHaveAttribute('data-content-left', 'none');

    // Turn on Invert Mouse
    await page.locator('[data-testid="btn-settings"]').click();
    await page.locator('[data-testid="setting-invert-mouse"]').check();
    await page.locator('[data-testid="btn-close-settings"]').click();

    // Now left click acts as secondary click, placing air
    await cell.click({ button: 'left' });
    await expect(cell).toHaveAttribute('data-content-left', 'air');
  });

  test('persists user settings in localStorage across page reloads', async ({ page }) => {
    await page.locator('[data-testid="btn-settings"]').click();
    await page.locator('[data-testid="setting-bigger-hints"]').check();
    await page.locator('[data-testid="setting-line-info"]').selectOption('missing');
    await page.locator('[data-testid="btn-close-settings"]').click();

    // Reload page
    await page.reload();
    await page.waitForSelector('[data-testid="cell-0-0"]');

    // Verify classes and opposite hints are still active
    await expect(page.locator('.game-container')).toHaveClass(/bigger-hints/);
    await expect(page.locator('[data-testid="row-hint-opposite-0"]')).toBeVisible();

    // Verify settings modal has saved values
    await page.locator('[data-testid="btn-settings"]').click();
    await expect(page.locator('[data-testid="setting-bigger-hints"]')).toBeChecked();
    await expect(page.locator('[data-testid="setting-line-info"]')).toHaveValue('missing');
  });

  test('disabling show bubbles hides background bubbles pseudo-elements', async ({ page }) => {
    const bgBeforeDisplay = async () => {
      return page.evaluate(() => {
        const bg = document.querySelector('.game-bg');
        if (!bg) return '';
        return window.getComputedStyle(bg, '::before').display;
      });
    };

    // Initially bubbles are enabled
    expect(await bgBeforeDisplay()).not.toBe('none');

    // Open settings and turn off show bubbles
    await page.locator('[data-testid="btn-settings"]').click();
    await page.locator('[data-testid="setting-show-bubbles"]').uncheck();
    await page.locator('[data-testid="btn-close-settings"]').click();

    // Now .no-bubbles is present and pseudo-elements are display: none
    await expect(page.locator('.game-container')).toHaveClass(/no-bubbles/);
    expect(await bgBeforeDisplay()).toBe('none');
  });

  test('toggles simple ? hints visibility and displays opposite line info correctly for ? rows', async ({ page }) => {
    // Navigate to Level 01/03 which has simple ? hints on rows 1, 2, 3
    await page.goto('/?level=Level 01/03');
    await page.waitForSelector('[data-testid="cell-0-0"]');

    // Row 1 hint should initially show '?' (hide_unknown is false by default)
    const rowHints = page.locator('.row-hint');
    await expect(rowHints.nth(1)).toContainText('?');
    await expect(rowHints.nth(2)).toContainText('?');

    // Open settings and enable "Hide simple '?' hints"
    await page.locator('[data-testid="btn-settings"]').click();
    await page.locator('[data-testid="setting-hide-unknown"]').check();
    await page.locator('[data-testid="btn-close-settings"]').click();

    // Now row 1 and row 2 hints should NOT contain '?'
    await expect(rowHints.nth(1)).not.toContainText('?');
    await expect(rowHints.nth(2)).not.toContainText('?');

    // Open settings and enable "Current value" opposite line info
    await page.locator('[data-testid="btn-settings"]').click();
    await page.locator('[data-testid="setting-line-info"]').selectOption('current');
    await page.locator('[data-testid="btn-close-settings"]').click();

    // Opposite hint on row 1 (which has hidden ? primary clue) should show current water count '0'
    const row1Opposite = page.locator('[data-testid="row-hint-opposite-1"]');
    await expect(row1Opposite).toBeVisible();
    await expect(row1Opposite).toContainText('0');

    // Switch opposite line info to "Missing value"
    await page.locator('[data-testid="btn-settings"]').click();
    await page.locator('[data-testid="setting-line-info"]').selectOption('missing');
    await page.locator('[data-testid="btn-close-settings"]').click();

    // For row 1, since target is unknown (?), missing value should NOT show
    await expect(row1Opposite).toHaveText('');
  });

  test('water preview displays ghost preview across all cells flooded in aquarium', async ({ page }) => {
    // Level 01/03 has columns 0, 1, 2 as a connected aquarium of height 4 (12 cells total)
    await page.goto('/?level=Level 01/03');
    await page.waitForSelector('[data-testid="cell-0-0"]');

    // Hovering cell 0-0 with Water tool should preview all 12 cells in columns 0, 1, 2
    const cell00 = page.locator('[data-testid="cell-0-0"]');
    await cell00.hover();

    const previews = page.locator('.cell-preview-water');
    await expect(previews).toHaveCount(12);

    // Hovering bottom row cell 3-0 should only preview cells at row 3 (columns 0, 1, 2 = 3 cells)
    const cell30 = page.locator('[data-testid="cell-3-0"]');
    await cell30.hover();
    await expect(previews).toHaveCount(3);
  });
});
