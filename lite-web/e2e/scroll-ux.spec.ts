import { test, expect, type Page } from './fixtures';

async function touchSwipe(page: Page, startX: number, startY: number, endX: number, endY: number, steps = 10) {
  const client = await page.context().newCDPSession(page);
  await client.send('Input.dispatchTouchEvent', {
    type: 'touchStart',
    touchPoints: [{ x: startX, y: startY, id: 1 }],
  });
  for (let i = 1; i <= steps; i++) {
    const x = startX + ((endX - startX) * i) / steps;
    const y = startY + ((endY - startY) * i) / steps;
    await client.send('Input.dispatchTouchEvent', {
      type: 'touchMove',
      touchPoints: [{ x, y, id: 1 }],
    });
  }
  await client.send('Input.dispatchTouchEvent', {
    type: 'touchEnd',
    touchPoints: [],
  });
  await client.detach();
}

test.describe('Scroll UX: Touch Hints & Desktop Scroll Down Button', () => {
  test.beforeEach(async ({ page }) => {
    await page.addInitScript(() => {
      localStorage.setItem('liquidum_help_seen', 'true');
      localStorage.setItem('liquidum_custom_id', 'TEST_KEY_12345');
    });
  });

  test.describe('Touch interactions on grid hints', () => {
    test.use({ hasTouch: true });

    test('dragging finger through row and column hints scrolls page without showing helper text or pinning hint', async ({ page }) => {
      await page.setViewportSize({ width: 375, height: 480 });
      await page.goto('/?mode=test');
      await expect(page.locator('.grid-board-card')).toBeVisible();

      // Load a larger level so the page is comfortably taller than 480px
      await page.evaluate(() => (window as any).loadLevelKey?.('Level 06/03'));
      const rowHint0 = page.locator('[data-testid="row-hint-0"]');
      const colHint0 = page.locator('[data-testid="col-hint-0"]');
      await expect(rowHint0).toBeVisible();

      const canScroll = await page.evaluate(() => document.documentElement.scrollHeight > window.innerHeight + 20);
      expect(canScroll).toBe(true);

      // Drag upward starting from row-hint-0 to scroll down
      const rowBox = (await rowHint0.boundingBox())!;
      await touchSwipe(
        page,
        rowBox.x + rowBox.width / 2,
        rowBox.y + rowBox.height / 2,
        rowBox.x + rowBox.width / 2,
        rowBox.y + rowBox.height / 2 - 140
      );

      await expect.poll(() => page.evaluate(() => window.scrollY)).toBeGreaterThan(20);
      await expect(page.locator('[data-testid="mobile-tooltip"]')).toHaveCount(0);
      await expect(rowHint0).not.toHaveClass(/hint-hovered/);

      // Scroll back to top and verify dragging through col-hint-0 also scrolls without helper text
      await page.evaluate(() => window.scrollTo(0, 0));
      const colBox = (await colHint0.boundingBox())!;
      await touchSwipe(
        page,
        colBox.x + colBox.width / 2,
        colBox.y + colBox.height / 2,
        colBox.x + colBox.width / 2,
        colBox.y + colBox.height / 2 - 140
      );

      await expect.poll(() => page.evaluate(() => window.scrollY)).toBeGreaterThan(20);
      await expect(page.locator('[data-testid="mobile-tooltip"]')).toHaveCount(0);
      await expect(colHint0).not.toHaveClass(/hint-hovered/);
    });

    test('tapping a hint still shows helper text and pins the highlight', async ({ page }) => {
      await page.setViewportSize({ width: 375, height: 667 });
      await page.goto('/?mode=test');
      const rowHint0 = page.locator('[data-testid="row-hint-0"]');
      await expect(rowHint0).toBeVisible();

      await rowHint0.tap();

      await expect(page.locator('[data-testid="mobile-tooltip"]')).toBeVisible();
      await expect(rowHint0).toHaveClass(/hint-hovered/);
    });

    test('dragging across cells still paints cells without scrolling', async ({ page }) => {
      await page.setViewportSize({ width: 375, height: 480 });
      await page.goto('/?mode=test');
      const cell01 = page.locator('[data-testid="cell-0-1"]');
      const cell02 = page.locator('[data-testid="cell-0-2"]');
      await expect(cell01).toBeVisible();

      const b0 = (await cell01.boundingBox())!;
      const b1 = (await cell02.boundingBox())!;
      await touchSwipe(
        page,
        b0.x + b0.width / 2,
        b0.y + b0.height / 2,
        b1.x + b1.width / 2,
        b1.y + b1.height / 2,
        8
      );

      await expect(cell01).toHaveAttribute('data-content-left', 'water');
      await expect(cell02).toHaveAttribute('data-content-left', 'water');
      const scrollY = await page.evaluate(() => window.scrollY);
      expect(scrollY).toBe(0);
    });
  });

  test.describe('Bottom-right scroll down arrow when content overflows viewport', () => {
    test('shows on iPhone SE (375x667) when content overflows (e.g. daily or win banner), scrolls down, and hides at bottom', async ({ page }) => {
      await page.setViewportSize({ width: 375, height: 667 });
      await page.goto('/');
      await expect(page.locator('.grid-board-card')).toBeVisible();

      const startBtn = page.locator('[data-testid="btn-start-puzzle"]');
      if (await startBtn.isVisible()) {
        await startBtn.click();
      }

      // Load a level whose content (or win banner) extends below 667px
      await page.evaluate(() => (window as any).loadLevelKey?.('Level 06/03'));
      const scrollBtn = page.locator('[data-testid="btn-scroll-down"]');
      await expect(scrollBtn).toBeVisible();

      const btnBox = (await scrollBtn.boundingBox())!;
      expect(btnBox.x + btnBox.width).toBeGreaterThan(375 - 40);
      expect(btnBox.y + btnBox.height).toBeGreaterThan(667 - 40);

      // Click to scroll down
      await scrollBtn.click();
      await expect.poll(() => page.evaluate(() => window.scrollY)).toBeGreaterThan(0);

      // Scroll all the way to the bottom -> arrow should hide
      await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
      await expect(scrollBtn).toBeHidden();
    });

    test('appears on mobile when winning makes the page taller than the screen', async ({ page }) => {
      await page.setViewportSize({ width: 375, height: 667 });
      await page.goto('/?mode=test');
      await expect(page.locator('.grid-board-card')).toBeVisible();

      const scrollBtn = page.locator('[data-testid="btn-scroll-down"]');
      // Small 3x3 test level fits inside 667px initially
      await expect(scrollBtn).toBeHidden();

      // Solve Level 01/01 so the win banner appears and pushes page height past 667px
      await page.click('[data-testid="cell-0-1"]');
      await page.click('[data-testid="cell-0-2"]');
      await page.click('[data-testid="cell-1-2"]');
      await page.click('[data-testid="cell-2-0"]');
      await page.click('[data-testid="cell-2-1"]');
      await page.click('[data-testid="cell-2-2"]');
      await expect(page.locator('[data-testid="win-banner"]')).toBeVisible();

      // Now the page overflows 667px, so the scroll-down arrow appears
      await expect(scrollBtn).toBeVisible();
      await scrollBtn.click();
      await expect.poll(() => page.evaluate(() => window.scrollY)).toBeGreaterThan(0);
    });

    test('shows on larger screens when scrollable, avoids Steam link, scrolls down on click, and hides at bottom', async ({ page }) => {
      await page.setViewportSize({ width: 1280, height: 550 });
      await page.goto('/?mode=test');
      await page.evaluate(() => (window as any).loadLevelKey?.('Level 06/03'));
      await expect(page.locator('.grid-board-card')).toBeVisible();

      const scrollBtn = page.locator('[data-testid="btn-scroll-down"]');
      await expect(scrollBtn).toBeVisible();

      // Verify it sits at the bottom-right and does not overlap the desktop Steam link
      const btnBox = (await scrollBtn.boundingBox())!;
      const steamLink = page.locator('a[href*="liteweb_persistent"]');
      await expect(steamLink).toBeVisible();
      const steamBox = (await steamLink.boundingBox())!;

      expect(btnBox.x + btnBox.width).toBeGreaterThan(1280 - 60);
      expect(btnBox.y + btnBox.height).toBeLessThanOrEqual(steamBox.y);

      // Click to scroll down
      await scrollBtn.click();
      await expect.poll(() => page.evaluate(() => window.scrollY)).toBeGreaterThan(50);

      // Scroll all the way to the bottom -> arrow should hide
      await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
      await expect(scrollBtn).toBeHidden();
    });

    test('shows on medium screens (769px - 1023px) and hides when page fits viewport', async ({ page }) => {
      await page.setViewportSize({ width: 900, height: 520 });
      await page.goto('/?mode=test');
      await page.evaluate(() => (window as any).loadLevelKey?.('Level 06/03'));
      await expect(page.locator('.grid-board-card')).toBeVisible();

      const scrollBtn = page.locator('[data-testid="btn-scroll-down"]');
      await expect(scrollBtn).toBeVisible();

      // Tall viewport where everything fits without scrolling
      await page.setViewportSize({ width: 1280, height: 1400 });
      await expect(scrollBtn).toBeHidden();
    });
  });
});
