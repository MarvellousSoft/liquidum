import { test, expect } from '@playwright/test';

test.describe('Drawing & Marker Feature', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/?mode=test');
    await expect(page.locator('[data-testid="tool-water"]')).toBeVisible();
    await expect(page.locator('[data-testid="btn-draw-toggle"]')).toBeVisible();
    await expect(page.locator('[data-testid="drawing-canvas"]')).toBeVisible();
  });

  test('toggle drawing mode with button, space, and escape', async ({ page }) => {
    const drawBtn = page.locator('[data-testid="btn-draw-toggle"]');
    const canvas = page.locator('[data-testid="drawing-canvas"]');

    // Initially drawing canvas is inactive
    await expect(canvas).toHaveClass(/is-inactive/);
    await expect(page.locator('[data-testid="draw-tool-pen"]')).toHaveCount(0);

    // 1. Click toggle button to enter drawing mode
    await drawBtn.click();
    await expect(canvas).toHaveClass(/is-active/);
    await expect(page.locator('[data-testid="draw-tool-pen"]')).toBeVisible();
    await expect(page.locator('[data-testid="draw-tool-eraser"]')).toBeVisible();
    await expect(page.locator('[data-testid="draw-color-picker"]')).toBeVisible();
    await expect(page.locator('[data-testid="draw-clear-all"]')).toBeVisible();

    // 2. Press Space to exit drawing mode
    await page.keyboard.press('Space');
    await expect(canvas).toHaveClass(/is-inactive/);
    await expect(page.locator('[data-testid="tool-water"]')).toBeVisible();

    // 3. Press Space to re-enter drawing mode
    await page.keyboard.press('Space');
    await expect(canvas).toHaveClass(/is-active/);

    // 4. Press Escape to exit drawing mode
    await page.keyboard.press('Escape');
    await expect(canvas).toHaveClass(/is-inactive/);

    // 5. Click toggle button, then click "Done" button to exit
    await drawBtn.click();
    await expect(canvas).toHaveClass(/is-active/);
    const doneBtn = page.locator('[data-testid="btn-draw-toggle"]');
    await doneBtn.click();
    await expect(canvas).toHaveClass(/is-inactive/);
  });

  test('drawing on canvas creates strokes and does not modify grid cells', async ({ page }) => {
    const canvas = page.locator('[data-testid="drawing-canvas"]');
    const cell00 = page.locator('[data-testid="cell-0-0"]');

    // Verify initial cell is empty
    await expect(cell00).toHaveAttribute('data-content-left', 'none');

    // Canvas should start with no non-transparent pixels
    const initialNonBlank = await canvas.evaluate((el: HTMLCanvasElement) => {
      const ctx = el.getContext('2d');
      if (!ctx) return 0;
      const data = ctx.getImageData(0, 0, el.width, el.height).data;
      let nonZero = 0;
      for (let i = 3; i < data.length; i += 4) {
        if (data[i] > 0) nonZero++;
      }
      return nonZero;
    });
    expect(initialNonBlank).toBe(0);

    // Enter drawing mode
    await page.locator('[data-testid="btn-draw-toggle"]').click();
    await expect(canvas).toHaveClass(/is-active/);

    // Drag mouse across the canvas over cell 0,0
    const box = await canvas.boundingBox();
    expect(box).not.toBeNull();
    if (!box) return;

    await page.mouse.move(box.x + 40, box.y + 40);
    await page.mouse.down();
    await page.mouse.move(box.x + 120, box.y + 120, { steps: 5 });
    await page.mouse.up();

    // Verify non-blank pixels were drawn
    const afterDrawNonBlank = await canvas.evaluate((el: HTMLCanvasElement) => {
      const ctx = el.getContext('2d');
      if (!ctx) return 0;
      const data = ctx.getImageData(0, 0, el.width, el.height).data;
      let nonZero = 0;
      for (let i = 3; i < data.length; i += 4) {
        if (data[i] > 0) nonZero++;
      }
      return nonZero;
    });
    expect(afterDrawNonBlank).toBeGreaterThan(50);

    // Crucial: Grid cell 0,0 was NOT modified (drawing is purely visual)
    await expect(cell00).toHaveAttribute('data-content-left', 'none');

    // Exit drawing mode
    await page.keyboard.press('Space');
    await expect(canvas).toHaveClass(/is-inactive/);

    // Strokes remain visible on canvas even when inactive
    const afterExitNonBlank = await canvas.evaluate((el: HTMLCanvasElement) => {
      const ctx = el.getContext('2d');
      if (!ctx) return 0;
      const data = ctx.getImageData(0, 0, el.width, el.height).data;
      let nonZero = 0;
      for (let i = 3; i < data.length; i += 4) {
        if (data[i] > 0) nonZero++;
      }
      return nonZero;
    });
    expect(afterExitNonBlank).toBe(afterDrawNonBlank);

    // Now clicking cell 0,0 with air (right click) places air normally
    await cell00.click({ button: 'right' });
    await expect(cell00).toHaveAttribute('data-content-left', 'air');
  });

  test('eraser brush erases drawn strokes', async ({ page }) => {
    const canvas = page.locator('[data-testid="drawing-canvas"]');

    // Enter drawing mode
    await page.locator('[data-testid="btn-draw-toggle"]').click();

    const box = await canvas.boundingBox();
    expect(box).not.toBeNull();
    if (!box) return;

    // Draw a stroke from (50, 50) to (150, 50)
    await page.mouse.move(box.x + 50, box.y + 50);
    await page.mouse.down();
    await page.mouse.move(box.x + 150, box.y + 50, { steps: 5 });
    await page.mouse.up();

    const drawnCount = await canvas.evaluate((el: HTMLCanvasElement) => {
      const ctx = el.getContext('2d');
      if (!ctx) return 0;
      const data = ctx.getImageData(0, 0, el.width, el.height).data;
      let nonZero = 0;
      for (let i = 3; i < data.length; i += 4) {
        if (data[i] > 0) nonZero++;
      }
      return nonZero;
    });
    expect(drawnCount).toBeGreaterThan(50);

    // Switch to eraser via eraser button
    await page.locator('[data-testid="draw-tool-eraser"]').click();
    await expect(canvas).toHaveClass(/is-eraser/);

    // Drag eraser over the middle of the stroke: (80, 50) to (120, 50)
    await page.mouse.move(box.x + 80, box.y + 50);
    await page.mouse.down();
    await page.mouse.move(box.x + 120, box.y + 50, { steps: 5 });
    await page.mouse.up();

    // Verify pixels were erased (fewer non-zero pixels than before)
    const afterEraseCount = await canvas.evaluate((el: HTMLCanvasElement) => {
      const ctx = el.getContext('2d');
      if (!ctx) return 0;
      const data = ctx.getImageData(0, 0, el.width, el.height).data;
      let nonZero = 0;
      for (let i = 3; i < data.length; i += 4) {
        if (data[i] > 0) nonZero++;
      }
      return nonZero;
    });
    expect(afterEraseCount).toBeLessThan(drawnCount);
    expect(afterEraseCount).toBeGreaterThan(0); // Ends of stroke remain

    // Press E to toggle eraser back to pen mode
    await page.keyboard.press('e');
    await expect(canvas).not.toHaveClass(/is-eraser/);
  });

  test('tab key toggles between paint brush and eraser in drawing mode', async ({ page }) => {
    const penTool = page.locator('[data-testid="draw-tool-pen"]');
    const eraserTool = page.locator('[data-testid="draw-tool-eraser"]');
    const canvas = page.locator('[data-testid="drawing-canvas"]');

    // Enter drawing mode - pen is selected by default
    await page.locator('[data-testid="btn-draw-toggle"]').click();
    await expect(penTool).toHaveClass(/tool-btn-draw-active/);
    await expect(eraserTool).toHaveClass(/tool-btn-draw-inactive/);
    await expect(canvas).not.toHaveClass(/is-eraser/);

    // Press Tab -> switches to Eraser
    await page.keyboard.press('Tab');
    await expect(eraserTool).toHaveClass(/tool-btn-draw-active/);
    await expect(penTool).toHaveClass(/tool-btn-draw-inactive/);
    await expect(canvas).toHaveClass(/is-eraser/);

    // Press Tab again -> switches back to Pen / Paint Brush
    await page.keyboard.press('Tab');
    await expect(penTool).toHaveClass(/tool-btn-draw-active/);
    await expect(eraserTool).toHaveClass(/tool-btn-draw-inactive/);
    await expect(canvas).not.toHaveClass(/is-eraser/);
  });

  test('right click uses opposite tool: erases while on brush, paints while on eraser', async ({ page }) => {
    const canvas = page.locator('[data-testid="drawing-canvas"]');
    const penTool = page.locator('[data-testid="draw-tool-pen"]');
    const eraserTool = page.locator('[data-testid="draw-tool-eraser"]');

    // Enter drawing mode - pen is selected by default
    await page.locator('[data-testid="btn-draw-toggle"]').click();
    await expect(penTool).toHaveClass(/tool-btn-draw-active/);
    await expect(eraserTool).toHaveClass(/tool-btn-draw-inactive/);
    await expect(canvas).not.toHaveClass(/is-eraser/);

    const box = await canvas.boundingBox();
    expect(box).not.toBeNull();
    if (!box) return;

    // 1. Draw a stroke with left-click: (50, 60) to (150, 60)
    await page.mouse.move(box.x + 50, box.y + 60);
    await page.mouse.down({ button: 'left' });
    await page.mouse.move(box.x + 150, box.y + 60, { steps: 5 });
    await page.mouse.up({ button: 'left' });

    const drawnCount = await canvas.evaluate((el: HTMLCanvasElement) => {
      const ctx = el.getContext('2d');
      if (!ctx) return 0;
      const data = ctx.getImageData(0, 0, el.width, el.height).data;
      let nonZero = 0;
      for (let i = 3; i < data.length; i += 4) if (data[i] > 0) nonZero++;
      return nonZero;
    });
    expect(drawnCount).toBeGreaterThan(50);

    // 2. While on brush: RIGHT-CLICK ERASES
    await page.mouse.move(box.x + 80, box.y + 60);
    await page.mouse.down({ button: 'right' });
    await expect(canvas).toHaveClass(/is-eraser/);
    await page.mouse.move(box.x + 120, box.y + 60, { steps: 5 });
    await page.mouse.up({ button: 'right' });

    // Verify stroke was erased in the middle
    const afterRightClickErase = await canvas.evaluate((el: HTMLCanvasElement) => {
      const ctx = el.getContext('2d');
      if (!ctx) return 0;
      const data = ctx.getImageData(0, 0, el.width, el.height).data;
      let nonZero = 0;
      for (let i = 3; i < data.length; i += 4) if (data[i] > 0) nonZero++;
      return nonZero;
    });
    expect(afterRightClickErase).toBeLessThan(drawnCount);
    expect(afterRightClickErase).toBeGreaterThan(0);

    // 3. Switch to Eraser tool via Tab
    await page.keyboard.press('Tab');
    await expect(eraserTool).toHaveClass(/tool-btn-draw-active/);
    await expect(canvas).toHaveClass(/is-eraser/);

    // 4. While on eraser: RIGHT-CLICK PAINTS
    await page.mouse.move(box.x + 90, box.y + 60);
    await page.mouse.down({ button: 'right' });
    // While right-clicking on eraser, cursor switches back to brush (not is-eraser)
    await expect(canvas).not.toHaveClass(/is-eraser/);
    await page.mouse.move(box.x + 110, box.y + 60, { steps: 5 });
    await page.mouse.up({ button: 'right' });

    // Verify strokes were painted back into the erased gap
    const afterRightClickPaint = await canvas.evaluate((el: HTMLCanvasElement) => {
      const ctx = el.getContext('2d');
      if (!ctx) return 0;
      const data = ctx.getImageData(0, 0, el.width, el.height).data;
      let nonZero = 0;
      for (let i = 3; i < data.length; i += 4) if (data[i] > 0) nonZero++;
      return nonZero;
    });
    expect(afterRightClickPaint).toBeGreaterThan(afterRightClickErase);

    // Tool in toolbar remains Eraser (NO mode toggling occurred)
    await expect(eraserTool).toHaveClass(/tool-btn-draw-active/);
    await expect(canvas).toHaveClass(/is-eraser/);
  });

  test('color picker cycles colors with button and shortcut C', async ({ page }) => {
    // Enter drawing mode
    await page.locator('[data-testid="btn-draw-toggle"]').click();

    const color1 = await page.evaluate(() => (window as any).getDrawColor());
    expect(color1).toBe('#ff6a6a');

    // Click color picker button
    await page.locator('[data-testid="draw-color-picker"]').click();
    const color2 = await page.evaluate(() => (window as any).getDrawColor());
    expect(color2).toBe('#3b82f6');

    // Press 'c' key to cycle again
    await page.keyboard.press('c');
    const color3 = await page.evaluate(() => (window as any).getDrawColor());
    expect(color3).toBe('#facc15');

    // Press 'c' key to cycle to green
    await page.keyboard.press('c');
    const color4 = await page.evaluate(() => (window as any).getDrawColor());
    expect(color4).toBe('#3adc6b');

    // Cycle back to first color
    await page.keyboard.press('c');
    const color5 = await page.evaluate(() => (window as any).getDrawColor());
    expect(color5).toBe('#ff6a6a');
  });

  test('clear all button and X shortcut clears everything on canvas', async ({ page }) => {
    const canvas = page.locator('[data-testid="drawing-canvas"]');

    // Enter drawing mode
    await page.locator('[data-testid="btn-draw-toggle"]').click();

    const box = await canvas.boundingBox();
    expect(box).not.toBeNull();
    if (!box) return;

    // Draw some strokes
    await page.mouse.move(box.x + 50, box.y + 50);
    await page.mouse.down();
    await page.mouse.move(box.x + 100, box.y + 100, { steps: 5 });
    await page.mouse.up();

    let nonZero = await canvas.evaluate((el: HTMLCanvasElement) => {
      const ctx = el.getContext('2d');
      if (!ctx) return 0;
      const data = ctx.getImageData(0, 0, el.width, el.height).data;
      let c = 0;
      for (let i = 3; i < data.length; i += 4) if (data[i] > 0) c++;
      return c;
    });
    expect(nonZero).toBeGreaterThan(0);

    // Click clear button
    await page.locator('[data-testid="draw-clear-all"]').click();

    await expect.poll(async () => {
      return await canvas.evaluate((el: HTMLCanvasElement) => {
        const ctx = el.getContext('2d');
        if (!ctx) return 0;
        const data = ctx.getImageData(0, 0, el.width, el.height).data;
        let c = 0;
        for (let i = 3; i < data.length; i += 4) if (data[i] > 0) c++;
        return c;
      });
    }).toBe(0);

    // Draw again and clear with shortcut 'x'
    await page.mouse.move(box.x + 60, box.y + 60);
    await page.mouse.down();
    await page.mouse.move(box.x + 90, box.y + 90, { steps: 5 });
    await page.mouse.up();

    nonZero = await canvas.evaluate((el: HTMLCanvasElement) => {
      const ctx = el.getContext('2d');
      if (!ctx) return 0;
      const data = ctx.getImageData(0, 0, el.width, el.height).data;
      let c = 0;
      for (let i = 3; i < data.length; i += 4) if (data[i] > 0) c++;
      return c;
    });
    expect(nonZero).toBeGreaterThan(0);

    await page.keyboard.press('x');

    await expect.poll(async () => {
      return await canvas.evaluate((el: HTMLCanvasElement) => {
        const ctx = el.getContext('2d');
        if (!ctx) return 0;
        const data = ctx.getImageData(0, 0, el.width, el.height).data;
        let c = 0;
        for (let i = 3; i < data.length; i += 4) if (data[i] > 0) c++;
        return c;
      });
    }).toBe(0);
  });

  test('restarting level clears canvas drawings', async ({ page }) => {
    const canvas = page.locator('[data-testid="drawing-canvas"]');

    // Enter drawing mode and draw
    await page.locator('[data-testid="btn-draw-toggle"]').click();

    const box = await canvas.boundingBox();
    expect(box).not.toBeNull();
    if (!box) return;

    await page.mouse.move(box.x + 50, box.y + 50);
    await page.mouse.down();
    await page.mouse.move(box.x + 100, box.y + 100, { steps: 5 });
    await page.mouse.up();

    // Exit drawing mode
    await page.keyboard.press('Space');

    // Restart level
    await page.locator('[data-testid="btn-restart"]').click();

    await expect.poll(async () => {
      return await canvas.evaluate((el: HTMLCanvasElement) => {
        const ctx = el.getContext('2d');
        if (!ctx) return 0;
        const data = ctx.getImageData(0, 0, el.width, el.height).data;
        let c = 0;
        for (let i = 3; i < data.length; i += 4) if (data[i] > 0) c++;
        return c;
      });
    }).toBe(0);
  });
});
