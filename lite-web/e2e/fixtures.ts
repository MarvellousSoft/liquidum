import { test as base, expect } from '@playwright/test';

export interface TestOptions {
  /**
   * Set to true if this test intentionally requires real network access to live PlayFab.
   * Default is false (all requests to *playfabapi.com* are blocked by default).
   */
  allowPlayFab?: boolean;
}

/**
 * Extended Playwright test runner with automatic PlayFab network blocking.
 *
 * By default, all network requests to PlayFab (*playfabapi.com*) are intercepted
 * and aborted to ensure zero live calls are made to production during E2E testing.
 *
 * Tests that specifically test PlayFab features can still provide their own mocks
 * via `page.route('**\/*playfabapi.com/**', ...)` (test-level page routes take precedence).
 *
 * If a test really needs live access, configure:
 * `test.use({ allowPlayFab: true });`
 */
export const test = base.extend<TestOptions>({
  allowPlayFab: [false, { option: true }],

  blockPlayFab: [
    async ({ context, allowPlayFab }, use) => {
      if (!allowPlayFab) {
        await context.route('**/*playfabapi.com/**', (route) => {
          route.abort('blockedbyclient');
        });
      }
      await use();
    },
    { auto: true },
  ],
});

export { expect };
