import { test, expect } from './fixtures';

const DONE_KEY = 'liquidum_tutorial_done';
const STEPS = ['Level 01/01', 'Level 02/01', 'Level 03/04', 'Level 04/01', 'Level 05/02'];

test.describe('Learn to play section', () => {
  test('opens by itself for a first-time visitor, instead of the help reference', async ({ page }) => {
    await page.goto('/');

    const tutorial = page.locator('[data-testid="tutorial-modal"]');
    await expect(tutorial).toBeVisible({ timeout: 5000 });
    // the help modal is the reference screen; a newcomer gets the played
    // version of the same rules
    await expect(page.locator('[data-testid="help-modal"]')).toBeHidden();

    const seen = await page.evaluate(() => localStorage.getItem('liquidum_help_seen'));
    expect(seen).toBe('true');

    await page.locator('[data-testid="btn-close-tutorial-modal"]').click();
    await expect(tutorial).toBeHidden();

    // returning visitor: no longer opens on its own
    await page.reload();
    await page.waitForLoadState('domcontentloaded');
    await expect(tutorial).toBeHidden();
  });

  test('lists every step and starts with none done', async ({ page }) => {
    await page.goto('/');
    const tutorial = page.locator('[data-testid="tutorial-modal"]');
    await expect(tutorial).toBeVisible({ timeout: 5000 });

    for (let i = 1; i <= STEPS.length; i++) {
      await expect(page.locator(`[data-testid="tutorial-step-${i}"]`)).toBeVisible();
    }
    await expect(page.locator(`[data-testid="tutorial-step-${STEPS.length + 1}"]`)).toHaveCount(0);
    await expect(page.locator('[data-testid="tutorial-progress"]')).toContainText(`0 of ${STEPS.length}`);
  });

  test('reopens from the button and plays a step with its lesson under the board', async ({ page }) => {
    await page.addInitScript(() => {
      localStorage.setItem('liquidum_help_seen', 'true');
    });
    await page.goto('/');

    const tutorial = page.locator('[data-testid="tutorial-modal"]');
    await expect(tutorial).toBeHidden();

    const openBtn = page.locator('[data-testid="btn-open-tutorial-modal"]');
    await expect(openBtn).toBeVisible();
    await openBtn.click();
    await expect(tutorial).toBeVisible();

    // third step is the one that teaches diagonals and unknown hints
    await page.locator('[data-testid="tutorial-step-3"]').click();
    await expect(tutorial).toBeHidden();

    const lesson = page.locator('[data-testid="tutorial-lesson"]');
    await expect(lesson).toBeVisible({ timeout: 5000 });
    await expect(page.locator('[data-testid="tutorial-lesson-step"]')).toContainText('Step 3 of 5');
    await expect(page.locator('[data-testid="tutorial-lesson-diagonals"]')).toBeVisible();
    await expect(page.locator('[data-testid="tutorial-lesson-unknownHints"]')).toBeVisible();

    // the lesson reuses the help modal's diagrams, so they must render here too
    await expect(lesson.locator('[data-testid^="tutorial-grid-"]').first()).toBeVisible();

    // and the board for that level is actually on screen
    await expect(page.locator('[data-testid="level-name-label"]')).toContainText('Level 03/04');
  });

  test('shows stored progress and no lesson panel outside the section', async ({ page }) => {
    await page.addInitScript(
      ([doneKey, steps]) => {
        localStorage.setItem('liquidum_help_seen', 'true');
        localStorage.setItem(doneKey, JSON.stringify([steps[0], steps[1]]));
      },
      [DONE_KEY, STEPS] as const
    );
    await page.goto('/');

    // daily mode: the board has no lesson under it
    await expect(page.locator('[data-testid="tutorial-lesson"]')).toHaveCount(0);

    await page.locator('[data-testid="btn-open-tutorial-modal"]').click();
    await expect(page.locator('[data-testid="tutorial-progress"]')).toContainText(`2 of ${STEPS.length}`);

    // the finished ones are marked, the rest are not
    await expect(page.locator('[data-testid="tutorial-step-1"] img')).toHaveCount(1);
    await expect(page.locator('[data-testid="tutorial-step-2"] img')).toHaveCount(1);
    await expect(page.locator('[data-testid="tutorial-step-3"] img')).toHaveCount(0);
  });

  test('a junk progress value does not break the section', async ({ page }) => {
    await page.addInitScript(
      ([doneKey]) => {
        localStorage.setItem('liquidum_help_seen', 'true');
        localStorage.setItem(doneKey, 'not json');
      },
      [DONE_KEY] as const
    );
    await page.goto('/');

    await page.locator('[data-testid="btn-open-tutorial-modal"]').click();
    await expect(page.locator('[data-testid="tutorial-modal"]')).toBeVisible();
    await expect(page.locator('[data-testid="tutorial-progress"]')).toContainText(`0 of ${STEPS.length}`);
  });
});
