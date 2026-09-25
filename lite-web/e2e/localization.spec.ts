import { test, expect } from '@playwright/test';

test.describe('Internationalization (i18n) & pt-BR Localization', () => {
  test('auto-detects pt-BR browser locale and displays Portuguese UI', async ({ page }) => {
    // Set browser language to pt-BR via init script
    await page.addInitScript(() => {
      Object.defineProperty(navigator, 'languages', {
        get: () => ['pt-BR', 'pt', 'en-US'],
      });
      Object.defineProperty(navigator, 'language', {
        get: () => 'pt-BR',
      });
      localStorage.setItem('liquidum_help_seen', 'true');
    });

    await page.goto('/');

    // Check toolbar buttons in Portuguese
    const waterBtn = page.locator('[data-testid="tool-water"]');
    await expect(waterBtn).toHaveAttribute('aria-label', 'Água');

    const undoBtn = page.locator('[data-testid="btn-undo"]');
    await expect(undoBtn.locator('.btn-text')).toHaveText('Desfazer');

    const helpBtn = page.locator('[data-testid="btn-help"]');
    await expect(helpBtn.locator('.btn-text')).toHaveText('Como Jogar');

    const shortcutsBtn = page.locator('[data-testid="btn-shortcuts"]');
    await expect(shortcutsBtn.locator('.btn-text')).toHaveText('Atalhos');

    const settingsBtn = page.locator('[data-testid="btn-settings"]');
    await expect(settingsBtn.locator('.btn-text')).toHaveText('Opções');

    // Open settings and check title
    await settingsBtn.click();
    const settingsModal = page.locator('[data-testid="settings-modal"]');
    await expect(settingsModal).toBeVisible();
    await expect(settingsModal.locator('h2')).toHaveText('Opções');

    // Check language select dropdown has 'system' selected by default
    const langSelect = page.locator('[data-testid="setting-language"]');
    await expect(langSelect).toBeVisible();
    await expect(langSelect).toHaveValue('system');
  });

  test('switches language dynamically via Settings dropdown', async ({ page }) => {
    await page.addInitScript(() => {
      localStorage.setItem('liquidum_help_seen', 'true');
    });

    await page.goto('/');

    // Open settings
    const settingsBtn = page.locator('[data-testid="btn-settings"]');
    await settingsBtn.click();

    const settingsModal = page.locator('[data-testid="settings-modal"]');
    await expect(settingsModal).toBeVisible();

    const langSelect = page.locator('[data-testid="setting-language"]');

    // Switch to Portuguese
    await langSelect.selectOption('pt-BR');

    // Verify modal header immediately changed to "Opções"
    await expect(settingsModal.locator('h2')).toHaveText('Opções');

    // Verify toolbar buttons immediately updated
    await expect(page.locator('[data-testid="tool-water"]')).toHaveAttribute('aria-label', 'Água');
    await expect(page.locator('[data-testid="btn-undo"] .btn-text')).toHaveText('Desfazer');

    // Switch back to English
    await langSelect.selectOption('en');
    await expect(settingsModal.locator('h2')).toHaveText('Settings');
    await expect(page.locator('[data-testid="tool-water"]')).toHaveAttribute('aria-label', 'Water');
    await expect(page.locator('[data-testid="btn-undo"] .btn-text')).toHaveText('Undo');
  });

  test('renders Account and Help modals with Portuguese translations', async ({ page }) => {
    await page.addInitScript(() => {
      // Force pt-BR in settings
      localStorage.setItem('liquidum_settings', JSON.stringify({ language: 'pt-BR' }));
      localStorage.setItem('liquidum_help_seen', 'true');
    });

    await page.goto('/');

    // 1. Open Help Modal
    const helpBtn = page.locator('[data-testid="btn-help"]');
    await helpBtn.click();
    const helpModal = page.locator('[data-testid="help-modal"]');
    await expect(helpModal).toBeVisible();
    await expect(helpModal.locator('h2')).toHaveText('Como Jogar');
    await expect(page.locator('[data-testid="btn-help-got-it"]')).toHaveText('Entendi');

    // Close Help Modal
    await page.locator('[data-testid="btn-close-help"]').click();
    await expect(helpModal).toBeHidden();

    // 2. Open Account Modal
    const accountBtn = page.locator('[data-testid="btn-account"]');
    await accountBtn.click();
    const accountModal = page.locator('[data-testid="account-modal"]');
    await expect(accountModal).toBeVisible();
    await expect(accountModal.locator('#account-modal-title')).toHaveText('Conta de Jogador & Perfil');
    await expect(page.locator('[data-testid="btn-save-display-name"]')).toHaveText('Salvar Nome');
    await expect(page.locator('[data-testid="btn-copy-key"]')).toContainText('Copiar Chave');

    // Close Account Modal
    await page.locator('[data-testid="btn-close-account"]').click();
    await expect(accountModal).toBeHidden();
  });
});
