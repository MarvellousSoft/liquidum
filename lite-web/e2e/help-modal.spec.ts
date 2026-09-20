import { test, expect } from '@playwright/test';

test.describe('Help Modal & Game Mechanics E2E Tests', () => {
  test('automatically opens help modal on first visit, but not on subsequent visits', async ({ page }) => {
    // 1. Visit with fresh storage (first-time visitor)
    await page.goto('/');
    
    // Help modal should be automatically open
    const helpModal = page.locator('[data-testid="help-modal"]');
    await expect(helpModal).toBeVisible({ timeout: 5000 });
    await expect(helpModal.locator('h2')).toHaveText(/How to Play/);

    // Verify localStorage has liquidum_help_seen set
    const seen = await page.evaluate(() => localStorage.getItem('liquidum_help_seen'));
    expect(seen).toBe('true');

    // Close the modal via "Got it" button
    const gotItBtn = page.locator('[data-testid="btn-help-got-it"]');
    await gotItBtn.click();
    await expect(helpModal).toBeHidden();

    // 2. Reload page (returning visitor) -> should NOT open automatically
    await page.reload();
    await page.waitForLoadState('domcontentloaded');
    await expect(helpModal).toBeHidden();
  });

  test('opens via toolbar "?" button and closes on close button and Esc', async ({ page }) => {
    // Mark as already seen so it does not auto-open on load
    await page.addInitScript(() => {
      localStorage.setItem('liquidum_help_seen', 'true');
    });

    await page.goto('/');
    const helpModal = page.locator('[data-testid="help-modal"]');
    await expect(helpModal).toBeHidden();

    // Click toolbar ? button
    const helpBtn = page.locator('[data-testid="btn-help"]');
    await expect(helpBtn).toBeVisible();
    await helpBtn.click();
    await expect(helpModal).toBeVisible();

    // Close via 'X' button
    const closeBtn = page.locator('[data-testid="btn-close-help"]');
    await closeBtn.click();
    await expect(helpModal).toBeHidden();

    // Open via 'h' keyboard shortcut
    await page.keyboard.press('h');
    await expect(helpModal).toBeVisible();

    // Close via 'Escape' key
    await page.keyboard.press('Escape');
    await expect(helpModal).toBeHidden();
  });

  test('displays "In Today\'s Puzzle" badges on active mechanics', async ({ page }) => {
    await page.addInitScript(() => {
      localStorage.setItem('liquidum_help_seen', 'true');
    });

    await page.goto('/');
    const helpBtn = page.locator('[data-testid="btn-help"]');
    await helpBtn.click();

    const helpModal = page.locator('[data-testid="help-modal"]');
    await expect(helpModal).toBeVisible();

    // Aquariums & Row/Col numbers are always in today's puzzle
    const aqCard = helpModal.locator('[data-testid="mechanic-card-aquariums"]');
    await expect(aqCard.locator('[data-testid="badge-in-todays-puzzle"]')).toHaveText("In Today's Puzzle");

    const lineCard = helpModal.locator('[data-testid="mechanic-card-lineNumbers"]');
    await expect(lineCard.locator('[data-testid="badge-in-todays-puzzle"]')).toHaveText("In Today's Puzzle");

    // Check today's theme banner is present
    const banner = helpModal.locator('[data-testid="today-theme-banner"]');
    await expect(banner).toBeVisible();
  });

  test('hides text on narrow screens for help and profile buttons', async ({ page }) => {
    await page.addInitScript(() => {
      localStorage.setItem('liquidum_help_seen', 'true');
    });

    // Set narrow mobile viewport
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto('/');

    const helpBtn = page.locator('[data-testid="btn-help"]');
    const accountBtn = page.locator('[data-testid="btn-account"]');

    await expect(helpBtn).toBeVisible();
    await expect(accountBtn).toBeVisible();

    // Text spans inside both buttons should be hidden (display: none)
    const helpText = helpBtn.locator('.btn-text');
    const accountText = accountBtn.locator('.btn-text');

    await expect(helpText).toBeHidden();
    await expect(accountText).toBeHidden();

    // Clicking help button still opens modal
    await helpBtn.click();
    await expect(page.locator('[data-testid="help-modal"]')).toBeVisible();
  });
});
