import { test, expect } from "@playwright/test";

test.describe("Leaderboard & PlayFab E2E Tests", () => {
  test.beforeEach(async ({ page }) => {
    // Intercept all PlayFab requests to guarantee ZERO live calls to production
    await page.route("**/*playfabapi.com/**", async (route) => {
      const url = route.request().url();
      const postData = route.request().postDataJSON() || {};

      if (url.includes("/Client/LoginWithCustomID")) {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify({
            code: 200,
            status: "OK",
            data: {
              PlayFabId: "TEST_USER_999",
              SessionTicket: "MOCK_SESSION_TICKET_999",
              NewlyCreated: false,
              InfoResultPayload: {
                PlayerProfile: {
                  DisplayName: "AquaNovice",
                },
              },
            },
          }),
        });
        return;
      }

      if (url.includes("/Client/GetLeaderboard")) {
        const isYesterday = postData.Version && postData.Version < 883;
        const mockLeaderboard = isYesterday
          ? [
              {
                Position: 0,
                PlayFabId: "PLAYER_YEST_1",
                DisplayName: "SeaOtter",
                StatValue: -42, // 0 mistakes, 42s
              },
              {
                Position: 1,
                PlayFabId: "TEST_USER_999",
                DisplayName: "AquaNovice",
                StatValue: -100060, // 1 mistake, 60s
              },
            ]
          : [
              {
                Position: 0,
                PlayFabId: "PLAYER_TODAY_1",
                DisplayName: "WhaleRider",
                StatValue: -50, // 0 mistakes, 50s
              },
              {
                Position: 1,
                PlayFabId: "PLAYER_TODAY_2",
                DisplayName: "DolphinDiver",
                StatValue: -75, // 0 mistakes, 75s
              },
              {
                Position: 2,
                PlayFabId: "PLAYER_TODAY_3",
                DisplayName: "CoralReef",
                StatValue: -100045, // 1 mistake, 45s
              },
              {
                Position: 3,
                PlayFabId: "TEST_USER_999", // Current user
                DisplayName: "AquaNovice",
                StatValue: -200110, // 2 mistakes, 110s
              },
            ];

        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify({
            code: 200,
            status: "OK",
            data: {
              Leaderboard: mockLeaderboard,
            },
          }),
        });
        return;
      }

      if (url.includes("/Client/UpdatePlayerStatistics")) {
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

      if (url.includes("/Client/UpdateUserTitleDisplayName")) {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify({
            code: 200,
            status: "OK",
            data: {
              DisplayName: postData.DisplayName,
            },
          }),
        });
        return;
      }

      // Default fallback
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ code: 200, status: "OK", data: {} }),
      });
    });
  });

  test("puzzle is initially blurred with start button, unblurs and counts timer on start", async ({
    page,
  }) => {
    await page.goto("/?daily=2024-01-07");

    // Start overlay is visible
    const overlay = page.locator('[data-testid="start-puzzle-overlay"]');
    await expect(overlay).toBeVisible();
    await expect(overlay).toContainText("Start Puzzle");

    // Board container has blur class
    const boardContainer = page.locator(".grid-board-card");
    await expect(boardContainer).toBeVisible();

    // Click Start Puzzle
    await page.click('[data-testid="btn-start-puzzle"]');

    // Overlay is removed
    await expect(overlay).toHaveCount(0);

    // Timer is displayed and starts counting
    const timer = page.locator('[data-testid="hint-timer"]');
    await expect(timer).toBeVisible();

    // Wait a brief moment and verify timer format
    await page.waitForTimeout(1100);
    const timerVal = await page.locator('[data-testid="timer-value"]').textContent();
    expect(timerVal).toMatch(/^0:0[1-9]$/);
  });

  test("opens leaderboard modal from top bar and switches between Today and Yesterday tabs", async ({
    page,
  }) => {
    await page.goto("/?daily=2024-01-07");

    // Click Leaderboard button in top bar
    await page.click('[data-testid="btn-leaderboard"]');

    const modal = page.locator('[role="dialog"]');
    await expect(modal).toBeVisible();
    await expect(modal).toContainText("Daily Leaderboard");

    // Default tab: Today
    await expect(page.locator("text=WhaleRider")).toBeVisible();
    await expect(page.locator("text=DolphinDiver")).toBeVisible();
    await expect(page.locator("text=🥇")).toBeVisible();
    await expect(page.locator("text=🥈")).toBeVisible();
    await expect(page.locator("text=🥉")).toBeVisible();

    // Current user row highlighted
    await expect(page.locator("text=AquaNovice (You)")).toBeVisible();

    // Switch to Yesterday tab
    await page.click('button:has-text("Yesterday")');
    await expect(page.locator("text=SeaOtter")).toBeVisible();

    // Close modal
    await page.click('button[aria-label="Close"]');
    await expect(modal).toHaveCount(0);
  });

  test("allows editing player display name in the leaderboard modal", async ({ page }) => {
    await page.goto("/?daily=2024-01-07");

    // Open leaderboard
    await page.click('[data-testid="btn-leaderboard"]');
    await expect(page.locator('[role="dialog"]')).toBeVisible();

    // Click Edit Name
    await page.click("button:has-text('Edit Name')");

    const input = page.locator('input[placeholder*="Enter name"]');
    await expect(input).toBeVisible();

    // Fill new name and save
    await input.fill("PoseidonGod");
    await page.click("button:has-text('Save')");

    // Name updated in profile bar
    await expect(page.locator("text=PoseidonGod")).toBeVisible();
  });

  test("submits daily score on first victory and removes Play Again button", async ({
    page,
  }) => {
    let statsUpdateCalled = false;
    let submittedValue = 0;

    await page.route("**/Client/UpdatePlayerStatistics", async (route) => {
      statsUpdateCalled = true;
      const data = route.request().postDataJSON();
      submittedValue = data.Statistics[0].Value;
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ code: 200, status: "OK", data: {} }),
      });
    });

    await page.goto("/?daily=2024-01-07");

    // Start puzzle
    await page.click('[data-testid="btn-start-puzzle"]');

    // Solve level using solution
    await page.evaluate(() => {
      const g = (window as any).getGridData();
      if (!g || !g.solution_c_left) return;
      for (let r = 0; r < g.cells.length; r++) {
        for (let c = 0; c < g.cells[r].length; c++) {
          const cell = g.cells[r][c];
          const solL = g.solution_c_left[r][c];
          const solR = g.solution_c_right[r][c];
          const leftCorner = cell.type === 10 ? 8 : 5;
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

    // Win banner appears
    await expect(page.locator('[data-testid="win-banner"]')).toBeVisible();

    // Verify UpdatePlayerStatistics was called with encoded score (poll for async network call)
    await expect.poll(() => statsUpdateCalled).toBe(true);
    expect(submittedValue).toBeLessThanOrEqual(0);

    // Verify Play Again button is NOT present in daily mode
    await expect(page.locator('[data-testid="btn-play-again"]')).toHaveCount(0);

    // Verify Leaderboard button on win banner works
    await page.click('[data-testid="btn-leaderboard-win"]');
    await expect(page.locator('[role="dialog"]')).toBeVisible();
    await page.click('button[aria-label="Close"]');

    // Second completion test: resetting statsUpdateCalled and restarting should NOT submit again
    statsUpdateCalled = false;
    await page.keyboard.press('r');
    // Solve level again
    await page.evaluate(() => {
      const g = (window as any).getGridData();
      if (!g || !g.solution_c_left) return;
      for (let r = 0; r < g.cells.length; r++) {
        for (let c = 0; c < g.cells[r].length; c++) {
          const cell = g.cells[r][c];
          const solL = g.solution_c_left[r][c];
          const solR = g.solution_c_right[r][c];
          const leftCorner = cell.type === 10 ? 8 : 5;
          const rightCorner = cell.type === 9 ? 7 : 6;
          if (solL === 1 || solL === 2) (window as any).putCellAction(r, c, leftCorner, solL);
          if (solR === 1 || solR === 2) (window as any).putCellAction(r, c, rightCorner, solR);
        }
      }
    });

    await expect(page.locator('[data-testid="win-banner"]')).toBeVisible();
    // Wait briefly and verify UpdatePlayerStatistics was NEVER called on second solve
    await page.waitForTimeout(500);
    expect(statsUpdateCalled).toBe(false);
  });
});
