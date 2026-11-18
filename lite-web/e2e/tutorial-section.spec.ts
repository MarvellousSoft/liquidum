import { test, expect } from './fixtures';

const DONE_KEY = 'liquidum_tutorial_done';
const STEPS = ['Level 00/01', 'Level 00/02', 'Level 02/01', 'Level 03/04',
               'Level 04/01', 'Level 05/02'];

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

    // the fourth tutorial teaches diagonals and unknown hints
    await page.locator('[data-testid="tutorial-step-4"]').click();
    await expect(tutorial).toBeHidden();

    const lesson = page.locator('[data-testid="tutorial-lesson"]');
    await expect(lesson).toBeVisible({ timeout: 5000 });
    await expect(page.locator('[data-testid="tutorial-lesson-step"]')).toContainText('Tutorial 4 of 6');
    await expect(page.locator('[data-testid="tutorial-lesson-diagonals"]')).toBeVisible();
    await expect(page.locator('[data-testid="tutorial-lesson-unknownHints"]')).toBeVisible();

    // the lesson reuses the help modal's diagrams, so they must render here too
    await expect(lesson.locator('[data-testid^="tutorial-grid-"]').first()).toBeVisible();

    // the raw level key is not shown while in a tutorial
    await expect(page.locator('[data-testid="level-name-label"]')).toHaveText('');
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
  test("marks which tutorials cover rules in todays level", async ({ page }) => {
    await page.addInitScript(() => localStorage.setItem('liquidum_help_seen', 'true'));
    await page.goto('/');
    await page.locator('[data-testid="btn-open-tutorial-modal"]').click();

    // aquariums and the line numbers are base rules of every daily, so the
    // first tutorial is always flagged, whatever day it is
    await expect(page.locator('[data-testid="tutorial-badge-today-1"]')).toBeVisible();
    await expect(page.locator('[data-testid="tutorial-badge-today-1"]')).toHaveText(/today/i);
  });

  test('opens the how-to-play reference from the section', async ({ page }) => {
    await page.addInitScript(() => localStorage.setItem('liquidum_help_seen', 'true'));
    await page.goto('/');
    await page.locator('[data-testid="btn-open-tutorial-modal"]').click();
    await page.locator('[data-testid="btn-tutorial-how-to-play"]').click();
    await expect(page.locator('[data-testid="help-modal"]')).toBeVisible();
  });

  test('the first tutorial explains the controls and links to the full list', async ({ page }) => {
    await page.addInitScript(() => localStorage.setItem('liquidum_help_seen', 'true'));
    await page.goto('/');
    await page.locator('[data-testid="btn-open-tutorial-modal"]').click();
    await page.locator('[data-testid="tutorial-step-1"]').click();

    await expect(page.locator('[data-testid="tutorial-lesson-controls"]')).toBeVisible();
    await page.locator('[data-testid="btn-tutorial-controls"]').click();
    await expect(page.locator('[data-testid="shortcuts-modal"]')).toBeVisible();

    // and only the first one carries it
    await page.locator('[data-testid="btn-close-shortcuts"]').click();
    await page.locator('[data-testid="btn-tutorial-lesson-back"]').click();
    await page.locator('[data-testid="tutorial-step-2"]').click();
    await expect(page.locator('[data-testid="tutorial-lesson"]')).toBeVisible();
    await expect(page.locator('[data-testid="tutorial-lesson-controls"]')).toHaveCount(0);
  });

  test('skipping goes to the daily level and is styled as a way out', async ({ page }) => {
    await page.addInitScript(() => localStorage.setItem('liquidum_help_seen', 'true'));
    await page.goto('/');
    await page.locator('[data-testid="btn-open-tutorial-modal"]').click();

    const skip = page.locator('[data-testid="btn-tutorial-play-daily"]');
    await expect(skip).toHaveClass(/tutorial-skip-btn/);
    await skip.click();

    await expect(page.locator('[data-testid="tutorial-modal"]')).toBeHidden();
    await expect(page.locator('[data-testid="tutorial-lesson"]')).toHaveCount(0);
    await expect(page.locator('[data-testid="daily-streak-badge"]')).toBeVisible();
  });
  test('on a phone the counters stay next to the board, above the lesson', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 812 });
    await page.addInitScript(() => localStorage.setItem('liquidum_help_seen', 'true'));
    await page.goto('/');
    await page.locator('[data-testid="btn-open-tutorial-modal"]').click();
    // the last tutorial has aquarium hints, so its counters card is a tall one
    await page.locator(`[data-testid="tutorial-step-${STEPS.length}"]`).click();
    await expect(page.locator('[data-testid="tutorial-lesson"]')).toBeVisible();

    const top = async (selector: string) => {
      const box = await page.locator(selector).boundingBox();
      return box!.y;
    };
    const boardBottom = (await page.locator('.grid-board-card').boundingBox())!;
    const counters = await top('[data-testid="grid-hints-card"]');
    const lesson = await top('[data-testid="tutorial-lesson"]');

    // board, then the counters, then the explanation - not the other way round
    expect(counters).toBeGreaterThan(boardBottom.y);
    expect(counters).toBeLessThan(lesson);
    // and the counters sit close under the board rather than past the lesson
    expect(counters - (boardBottom.y + boardBottom.height)).toBeLessThan(80);
  });

  test('on a desktop the lesson still sits below the board', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 900 });
    await page.addInitScript(() => localStorage.setItem('liquidum_help_seen', 'true'));
    await page.goto('/');
    await page.locator('[data-testid="btn-open-tutorial-modal"]').click();
    await page.locator('[data-testid="tutorial-step-1"]').click();
    await expect(page.locator('[data-testid="tutorial-lesson"]')).toBeVisible();

    const board = (await page.locator('.grid-board-card').boundingBox())!;
    const lesson = (await page.locator('[data-testid="tutorial-lesson"]').boundingBox())!;
    const hints = (await page.locator('[data-testid="grid-hints-card"]').boundingBox())!;
    expect(lesson.y).toBeGreaterThan(board.y + board.height - 1);
    // hints card keeps its place as the left column, beside the board
    expect(hints.x).toBeLessThan(board.x);
    expect(Math.abs(hints.y - board.y)).toBeLessThan(40);
  });
});
