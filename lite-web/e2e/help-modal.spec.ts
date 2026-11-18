import { test, expect } from './fixtures';

test.describe('Help Modal & Game Mechanics E2E Tests', () => {
  // A first-time visitor is now sent to the learn-to-play section instead of
  // this reference screen - see e2e/tutorial-section.spec.ts. The help modal
  // stays available on demand, and still must not pop up by itself.
  test('does not open by itself on a first visit, and the tutorial does', async ({ page }) => {
    await page.goto('/');

    const helpModal = page.locator('[data-testid="help-modal"]');
    await expect(page.locator('[data-testid="tutorial-modal"]')).toBeVisible({ timeout: 5000 });
    await expect(helpModal).toBeHidden();

    const seen = await page.evaluate(() => localStorage.getItem('liquidum_help_seen'));
    expect(seen).toBe('true');

    await page.locator('[data-testid="btn-close-tutorial-modal"]').click();

    // reload as a returning visitor: neither screen opens on its own
    await page.reload();
    await page.waitForLoadState('domcontentloaded');
    await expect(helpModal).toBeHidden();
    await expect(page.locator('[data-testid="tutorial-modal"]')).toBeHidden();
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

  test('on narrow screens, opens help modal via mobile hamburger menu', async ({ page }) => {
    await page.addInitScript(() => {
      localStorage.setItem('liquidum_help_seen', 'true');
    });

    // Set narrow mobile viewport
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto('/');

    // Desktop toolbar buttons are hidden on mobile
    await expect(page.locator('[data-testid="btn-help"]')).toBeHidden();
    await expect(page.locator('[data-testid="btn-account"]')).toBeHidden();

    // Hamburger button is visible
    const hamburgerBtn = page.locator('[data-testid="btn-hamburger"]');
    await expect(hamburgerBtn).toBeVisible();
    await hamburgerBtn.click();

    // Help and account items are visible in mobile sidebar
    const sidebarHelpBtn = page.locator('[data-testid="sidebar-btn-help"]');
    const sidebarAccountBtn = page.locator('[data-testid="sidebar-btn-account"]');
    await expect(sidebarHelpBtn).toBeVisible();
    await expect(sidebarAccountBtn).toBeVisible();

    // Clicking help item opens help modal
    await sidebarHelpBtn.click();
    await expect(page.locator('[data-testid="help-modal"]')).toBeVisible();
  });

  test('displays account recovery key note and links to account modal', async ({ page }) => {
    await page.addInitScript(() => {
      localStorage.setItem('liquidum_help_seen', 'true');
    });

    await page.goto('/');
    const helpBtn = page.locator('[data-testid="btn-help"]');
    await helpBtn.click();

    const note = page.locator('[data-testid="help-recovery-note"]');
    await expect(note).toBeVisible();
    await expect(note).toContainText('restore it here to keep your leaderboard presence and streak.');

    const hereLink = note.locator('[data-testid="link-open-account"]');
    await expect(hereLink).toBeVisible();
    await expect(hereLink).toHaveText('here');

    // Click "here" link
    await hereLink.click();

    // Help modal should close and Account modal should open
    await expect(page.locator('[data-testid="help-modal"]')).toBeHidden();
    await expect(page.locator('[data-testid="account-modal"]')).toBeVisible();
  });
});
