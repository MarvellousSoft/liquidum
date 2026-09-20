import { test, expect } from "@playwright/test";

test.describe("Account Modal & Profile E2E Tests", () => {
  let currentUser = {
    displayName: "AquaPlayer",
    avatarUrl: "https://example.com/avatar1.png",
    playFabId: "TEST_USER_123",
    customId: "KEY_ORIGINAL_111",
  };

  test.beforeEach(async ({ page }) => {
    currentUser = {
      displayName: "AquaPlayer",
      avatarUrl: "https://example.com/avatar1.png",
      playFabId: "TEST_USER_123",
      customId: "KEY_ORIGINAL_111",
    };

    // Pre-populate custom ID and mark help as seen before page loads
    await page.addInitScript((initKey) => {
      localStorage.setItem("liquidum_custom_id", initKey);
      localStorage.setItem("liquidum_help_seen", "true");
    }, currentUser.customId);

    // Mock image requests to prevent broken image load errors
    await page.route("**/*.png*", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "image/png",
        body: Buffer.from(
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
          "base64"
        ),
      });
    });

    // Mock all PlayFab network requests
    await page.route("**/*playfabapi.com/**", async (route) => {
      const url = route.request().url();
      const postData = route.request().postDataJSON() || {};

      if (url.includes("/Client/LoginWithCustomID")) {
        const customId = postData.CustomId || currentUser.customId;
        if (customId === "KEY_RESTORED_222") {
          currentUser = {
            displayName: "RestoredCaptain",
            avatarUrl: "https://example.com/restored-avatar.png",
            playFabId: "TEST_USER_222",
            customId: "KEY_RESTORED_222",
          };
        }

        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify({
            code: 200,
            status: "OK",
            data: {
              PlayFabId: currentUser.playFabId,
              SessionTicket: "MOCK_SESSION_TICKET_OK",
              NewlyCreated: false,
              InfoResultPayload: {
                PlayerProfile: {
                  DisplayName: currentUser.displayName,
                  AvatarUrl: currentUser.avatarUrl,
                },
              },
            },
          }),
        });
        return;
      }

      if (url.includes("/Client/UpdateUserTitleDisplayName")) {
        currentUser.displayName = postData.DisplayName;
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify({
            code: 200,
            status: "OK",
            data: {
              DisplayName: currentUser.displayName,
            },
          }),
        });
        return;
      }

      if (url.includes("/Client/UpdateAvatarUrl")) {
        currentUser.avatarUrl = postData.ImageUrl || null;
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify({
            code: 200,
            status: "OK",
            data: {},
          }),
        });
        return;
      }

      if (url.includes("/Client/GetLeaderboard")) {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify({
            code: 200,
            status: "OK",
            data: {
              Leaderboard: [],
            },
          }),
        });
        return;
      }

      await route.fallback();
    });

    await page.goto("/?mode=daily");
    await page.waitForLoadState("domcontentloaded");
  });

  test("displays account button with avatar and display name in toolbar", async ({ page }) => {
    const accountBtn = page.locator('[data-testid="btn-account"]');
    await expect(accountBtn).toBeVisible();
    await expect(accountBtn).toContainText("AquaPlayer");

    // Avatar image should be rendered
    const avatarImg = accountBtn.locator("img");
    await expect(avatarImg).toBeVisible();
    await expect(avatarImg).toHaveAttribute("src", "https://example.com/avatar1.png");
  });

  test("opens account modal when account button is clicked and closes on close button or Esc", async ({ page }) => {
    const accountBtn = page.locator('[data-testid="btn-account"]');
    await accountBtn.click();

    const modal = page.locator('[data-testid="account-modal"]');
    await expect(modal).toBeVisible();
    await expect(modal.locator("#account-modal-title")).toContainText("Player Account & Profile");

    // Close via close button
    const closeBtn = page.locator('[data-testid="btn-close-account"]');
    await closeBtn.click();
    await expect(modal).not.toBeVisible();

    // Reopen and close via Escape
    await accountBtn.click();
    await expect(modal).toBeVisible();
    await page.keyboard.press("Escape");
    await expect(modal).not.toBeVisible();
  });

  test("allows changing display name and updates header button", async ({ page }) => {
    await page.locator('[data-testid="btn-account"]').click();
    const modal = page.locator('[data-testid="account-modal"]');
    await expect(modal).toBeVisible();

    const nameInput = page.locator('[data-testid="input-display-name"]');
    const saveNameBtn = page.locator('[data-testid="btn-save-display-name"]');

    // Validation: too short
    await nameInput.fill("Hi");
    await saveNameBtn.click();
    const nameMsg = page.locator('[data-testid="name-message"]');
    await expect(nameMsg).toContainText("between 3 and 25 characters");

    // Valid update
    await nameInput.fill("MasterOfWater");
    await saveNameBtn.click();
    await expect(nameMsg).toContainText("Name updated successfully!");

    // Header account button should reflect updated name immediately
    const accountBtn = page.locator('[data-testid="btn-account"]');
    await expect(accountBtn).toContainText("MasterOfWater");
  });

  test("allows updating and removing profile picture URL", async ({ page }) => {
    await page.locator('[data-testid="btn-account"]').click();
    const modal = page.locator('[data-testid="account-modal"]');
    await expect(modal).toBeVisible();

    const avatarInput = page.locator('[data-testid="input-avatar-url"]');
    const saveAvatarBtn = page.locator('[data-testid="btn-save-avatar"]');
    const avatarMsg = page.locator('[data-testid="avatar-message"]');

    // Change avatar URL
    await avatarInput.fill("https://example.com/new-pfp.png");
    await saveAvatarBtn.click();
    await expect(avatarMsg).toContainText("Avatar updated successfully!");

    // Check header account button updated image src
    const accountImg = page.locator('[data-testid="btn-account"] img');
    await expect(accountImg).toHaveAttribute("src", "https://example.com/new-pfp.png");

    // Remove / clear avatar
    const removeBtn = page.locator('[data-testid="btn-remove-avatar"]');
    await removeBtn.click();
    await expect(avatarMsg).toContainText("Avatar removed.");

    // Header button should fallback to emoji icon
    await expect(page.locator('[data-testid="btn-account"] img')).not.toBeVisible();
    await expect(page.locator('[data-testid="btn-account"]')).toContainText("👤");
  });

  test("allows revealing and copying account recovery key", async ({ page }) => {
    await page.locator('[data-testid="btn-account"]').click();
    const modal = page.locator('[data-testid="account-modal"]');
    await expect(modal).toBeVisible();

    const keyInput = page.locator('[data-testid="input-recovery-key"]');
    await expect(keyInput).toHaveAttribute("type", "password");

    // Toggle reveal
    const toggleBtn = page.locator('[data-testid="btn-toggle-key-visibility"]');
    await toggleBtn.click();
    await expect(keyInput).toHaveAttribute("type", "text");
    await expect(keyInput).toHaveValue("KEY_ORIGINAL_111");

    // Toggle hide
    await toggleBtn.click();
    await expect(keyInput).toHaveAttribute("type", "password");

    // Copy key button
    const copyBtn = page.locator('[data-testid="btn-copy-key"]');
    await copyBtn.click();
    await expect(copyBtn).toContainText("Copied!");
  });

  test("restores account by pasting recovery key", async ({ page }) => {
    // Automatically accept window.confirm for account restore
    page.on("dialog", async (dialog) => {
      await dialog.accept();
    });

    await page.locator('[data-testid="btn-account"]').click();
    const modal = page.locator('[data-testid="account-modal"]');
    await expect(modal).toBeVisible();

    const restoreInput = page.locator('[data-testid="input-restore-key"]');
    const restoreBtn = page.locator('[data-testid="btn-restore-key"]');

    // Attempt restoring with empty key should be disabled
    await expect(restoreBtn).toBeDisabled();

    // Paste recovery key
    await restoreInput.fill("KEY_RESTORED_222");
    await expect(restoreBtn).toBeEnabled();
    await restoreBtn.click();

    // Check success message
    const restoreMsg = page.locator('[data-testid="restore-message"]');
    await expect(restoreMsg).toContainText("Account restored! Welcome, RestoredCaptain.");

    // Check account key input now shows new key
    const keyInput = page.locator('[data-testid="input-recovery-key"]');
    await page.locator('[data-testid="btn-toggle-key-visibility"]').click();
    await expect(keyInput).toHaveValue("KEY_RESTORED_222");

    // Check header account button updated
    const accountBtn = page.locator('[data-testid="btn-account"]');
    await expect(accountBtn).toContainText("RestoredCaptain");
    await expect(accountBtn.locator("img")).toHaveAttribute("src", "https://example.com/restored-avatar.png");
  });
});
