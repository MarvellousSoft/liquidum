import { test, expect } from "@playwright/test";

test.describe("Mobile UX & Responsiveness E2E Tests", () => {
  test.beforeEach(async ({ page }) => {
    await page.addInitScript(() => {
      localStorage.setItem("liquidum_help_seen", "true");
      localStorage.setItem("liquidum_custom_id", "TEST_KEY_12345");
    });
  });

  test("account modal buttons do not overflow horizontally on mobile viewport", async ({ page }) => {
    // Emulate small mobile viewport
    await page.setViewportSize({ width: 360, height: 740 });
    await page.goto("/");

    // Open Account Modal
    const btnAccount = page.locator('[data-testid="btn-account"]');
    await expect(btnAccount).toBeVisible();
    await btnAccount.click();

    const accountModal = page.locator('[data-testid="account-modal"]');
    await expect(accountModal).toBeVisible();

    const dialog = accountModal.locator('.shortcuts-dialog');
    await expect(dialog).toBeVisible();
    const dialogBox = await dialog.boundingBox();
    expect(dialogBox).not.toBeNull();

    // Verify key action buttons are all contained within dialog bounds
    const buttonsToCheck = [
      page.locator('[data-testid="btn-save-avatar"]'),
      page.locator('[data-testid="btn-save-display-name"]'),
      page.locator('[data-testid="btn-copy-key"]'),
      page.locator('[data-testid="btn-toggle-key-visibility"]'),
      page.locator('[data-testid="btn-restore-key"]'),
    ];

    for (const btn of buttonsToCheck) {
      await expect(btn).toBeVisible();
      const btnBox = await btn.boundingBox();
      expect(btnBox).not.toBeNull();

      // Right edge of button must not exceed right edge of dialog
      const dialogRight = dialogBox!.x + dialogBox!.width;
      const btnRight = btnBox!.x + btnBox!.width;
      expect(btnRight).toBeLessThanOrEqual(dialogRight + 1); // 1px rounding tolerance
    }
  });

  test("opening leaderboard modal locks body scroll to prevent background scrolling", async ({ page }) => {
    await page.goto("/");

    // Body should initially not be locked
    const isInitiallyLocked = await page.evaluate(() => document.body.classList.contains("modal-open"));
    expect(isInitiallyLocked).toBe(false);

    // Open Leaderboard Modal
    const btnLeaderboard = page.locator('[data-testid="btn-leaderboard"]');
    if (await btnLeaderboard.isVisible()) {
      await btnLeaderboard.click();
    } else {
      // In case desktop sidepanel is visible, simulate mobile viewport
      await page.setViewportSize({ width: 400, height: 800 });
      await btnLeaderboard.click();
    }

    const leaderboardModal = page.locator('[data-testid="leaderboard-modal"]');
    await expect(leaderboardModal).toBeVisible();

    // Check body lock class and style
    const isLockedWhenOpen = await page.evaluate(() => {
      return document.body.classList.contains("modal-open") && document.body.style.overflow === "hidden";
    });
    expect(isLockedWhenOpen).toBe(true);

    // Close Leaderboard Modal
    const closeBtn = page.locator('[data-testid="btn-close-leaderboard"]');
    await closeBtn.click();
    await expect(leaderboardModal).toHaveCount(0);

    // Body lock should be removed (wait for passive effect cleanup)
    await expect(page.locator("body")).not.toHaveClass(/modal-open/);
    const bodyOverflow = await page.evaluate(() => document.body.style.overflow);
    expect(bodyOverflow).not.toBe("hidden");
  });

  test("shortcuts modal defaults to touch controls on mobile and supports switching", async ({ page }) => {
    // Emulate mobile device
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto("/");

    // Open shortcuts modal
    const btnShortcuts = page.locator('[data-testid="btn-shortcuts"]');
    await expect(btnShortcuts).toBeVisible();
    await btnShortcuts.click();

    const shortcutsModal = page.locator('[data-testid="shortcuts-modal"]');
    await expect(shortcutsModal).toBeVisible();

    // On mobile, it should default to Touch tab
    const touchContent = shortcutsModal.locator('[data-testid="shortcuts-touch-content"]');
    await expect(touchContent).toBeVisible();
    await expect(shortcutsModal).toContainText("Board Gestures");
    await expect(shortcutsModal).toContainText("Tap Cell");
    await expect(shortcutsModal).toContainText("Hold Cell (Long Press)");
    await expect(shortcutsModal).toContainText("Drag Finger");

    // Click Keyboard tab
    const keyboardTab = page.locator('[data-testid="tab-shortcuts-keyboard"]');
    await expect(keyboardTab).toBeVisible();
    await keyboardTab.click();

    // Should now show keyboard shortcuts
    const keyboardContent = shortcutsModal.locator('[data-testid="shortcuts-keyboard-content"]');
    await expect(keyboardContent).toBeVisible();
    await expect(shortcutsModal).toContainText("Quick Hover Keys");
    await expect(shortcutsModal).toContainText("Tool Selection");

    // Click back to Touch tab
    const touchTab = page.locator('[data-testid="tab-shortcuts-touch"]');
    await touchTab.click();
    await expect(touchContent).toBeVisible();
  });
});
