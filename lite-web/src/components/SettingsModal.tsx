import { h } from 'preact';
import { useEffect } from 'preact/hooks';
import type { GameSettings } from '../engine/SettingsManager';
import { useTranslation } from '../i18n';
import { useModalScrollLock } from '../utils/scrollLock';

export interface SettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
  settings: GameSettings;
  updateSetting: <K extends keyof GameSettings>(key: K, value: GameSettings[K]) => void;
}

export function SettingsModal({ isOpen, onClose, settings, updateSetting }: SettingsModalProps) {
  useModalScrollLock(isOpen);
  const { t } = useTranslation();

  if (!isOpen) return null;

  return (
    <div
      data-testid="settings-modal"
      class="modal-backdrop"
      onClick={onClose}
      onTouchMove={(e) => {
        if (e.target === e.currentTarget) {
          e.preventDefault();
        }
      }}
    >
      <div
        class="shortcuts-dialog settings-dialog"
        onClick={(e) => e.stopPropagation()}
      >
        <div class="shortcuts-header">
          <div class="flex items-center gap-2">
            <span class="text-xl">⚙️</span>
            <h2 class="shortcuts-title godot-text-outline">{t('settings.title')}</h2>
          </div>
          <button
            data-testid="btn-close-settings"
            onClick={onClose}
            class="shortcuts-close-btn"
            title={t('account.close')}
            aria-label={t('account.close')}
          >
            ✕
          </button>
        </div>

        <div class="settings-content">
          {/* DISPLAY SECTION */}
          <div class="settings-section">
            <h3 class="settings-section-title">
              <span>🎨</span> {t('settings.section_display')}
            </h3>

            {/* Language */}
            <div class="setting-item">
              <div class="setting-info">
                <span class="setting-title">{t('settings.language_title')}</span>
                <span class="setting-desc">{t('settings.language_desc')}</span>
              </div>
              <select
                data-testid="setting-language"
                value={settings.language || 'system'}
                onChange={(e) => updateSetting('language', e.currentTarget.value as any)}
                class="setting-select"
              >
                <option value="system">{t('settings.lang_system')}</option>
                <option value="en">{t('settings.lang_en')}</option>
                <option value="pt-BR">{t('settings.lang_pt_br')}</option>
              </select>
            </div>

            {/* Dark Mode */}
            <div class="setting-item">
              <div class="setting-info">
                <span class="setting-title">{t('settings.dark_mode_title')}</span>
                <span class="setting-desc">{t('settings.dark_mode_desc')}</span>
              </div>
              <label class="setting-toggle">
                <input
                  type="checkbox"
                  data-testid="setting-dark-mode"
                  checked={settings.dark_mode}
                  onChange={(e) => updateSetting('dark_mode', e.currentTarget.checked)}
                  class="checkbox-input"
                />
              </label>
            </div>

            {/* Show Bubbles */}
            <div class="setting-item">
              <div class="setting-info">
                <span class="setting-title">{t('settings.show_bubbles_title')}</span>
                <span class="setting-desc">{t('settings.show_bubbles_desc')}</span>
              </div>
              <label class="setting-toggle">
                <input
                  type="checkbox"
                  data-testid="setting-show-bubbles"
                  checked={settings.show_bubbles}
                  onChange={(e) => updateSetting('show_bubbles', e.currentTarget.checked)}
                  class="checkbox-input"
                />
              </label>
            </div>
          </div>

          {/* GAMEPLAY SECTION */}
          <div class="settings-section">
            <h3 class="settings-section-title">
              <span>🎮</span> {t('settings.section_gameplay')}
            </h3>

            {/* Incomplete line info */}
            <div class="setting-item">
              <div class="setting-info">
                <span class="setting-title">{t('settings.line_info_title')}</span>
                <span class="setting-desc">{t('settings.line_info_desc')}</span>
              </div>
              <select
                data-testid="setting-line-info"
                value={settings.line_info}
                onChange={(e) => updateSetting('line_info', e.currentTarget.value as any)}
                class="setting-select"
              >
                <option value="none">{t('settings.line_info_none')}</option>
                <option value="missing">{t('settings.line_info_missing')}</option>
                <option value="current">{t('settings.line_info_current')}</option>
              </select>
            </div>

            {/* Highlight finished rows/columns */}
            <div class="setting-item">
              <div class="setting-info">
                <span class="setting-title">{t('settings.highlight_hints_title')}</span>
                <span class="setting-desc">{t('settings.highlight_hints_desc')}</span>
              </div>
              <label class="setting-toggle">
                <input
                  type="checkbox"
                  data-testid="setting-highlight-hints"
                  checked={settings.highlight_finished_row_col}
                  onChange={(e) => updateSetting('highlight_finished_row_col', e.currentTarget.checked)}
                  class="checkbox-input"
                />
              </label>
            </div>

            {/* Highlight hovered line */}
            <div class="setting-item">
              <div class="setting-info">
                <span class="setting-title">{t('settings.highlight_grid_title')}</span>
                <span class="setting-desc">{t('settings.highlight_grid_desc')}</span>
              </div>
              <label class="setting-toggle">
                <input
                  type="checkbox"
                  data-testid="setting-highlight-grid"
                  checked={settings.highlight_grid}
                  onChange={(e) => updateSetting('highlight_grid', e.currentTarget.checked)}
                  class="checkbox-input"
                />
              </label>
            </div>

            {/* Show water preview */}
            <div class="setting-item">
              <div class="setting-info">
                <span class="setting-title">{t('settings.show_preview_title')}</span>
                <span class="setting-desc">{t('settings.show_preview_desc')}</span>
              </div>
              <label class="setting-toggle">
                <input
                  type="checkbox"
                  data-testid="setting-show-preview"
                  checked={settings.show_grid_preview}
                  onChange={(e) => updateSetting('show_grid_preview', e.currentTarget.checked)}
                  class="checkbox-input"
                />
              </label>
            </div>

            {/* Hide simple "?" hints */}
            <div class="setting-item">
              <div class="setting-info">
                <span class="setting-title">{t('settings.hide_unknown_title')}</span>
                <span class="setting-desc">{t('settings.hide_unknown_desc')}</span>
              </div>
              <label class="setting-toggle">
                <input
                  type="checkbox"
                  data-testid="setting-hide-unknown"
                  checked={settings.hide_unknown}
                  onChange={(e) => updateSetting('hide_unknown', e.currentTarget.checked)}
                  class="checkbox-input"
                />
              </label>
            </div>

            {/* Color "?" hints */}
            <div class="setting-item">
              <div class="setting-info">
                <span class="setting-title">{t('settings.progress_on_unknown_title')}</span>
                <span class="setting-desc">{t('settings.progress_on_unknown_desc')}</span>
              </div>
              <label class="setting-toggle">
                <input
                  type="checkbox"
                  data-testid="setting-progress-unknown"
                  checked={settings.progress_on_unknown}
                  onChange={(e) => updateSetting('progress_on_unknown', e.currentTarget.checked)}
                  class="checkbox-input"
                />
              </label>
            </div>

            {/* Show timer */}
            <div class="setting-item">
              <div class="setting-info">
                <span class="setting-title">{t('settings.show_timer_title')}</span>
                <span class="setting-desc">{t('settings.show_timer_desc')}</span>
              </div>
              <label class="setting-toggle">
                <input
                  type="checkbox"
                  data-testid="setting-show-timer"
                  checked={settings.show_timer}
                  onChange={(e) => updateSetting('show_timer', e.currentTarget.checked)}
                  class="checkbox-input"
                />
              </label>
            </div>

            {/* Skip animations */}
            <div class="setting-item">
              <div class="setting-info">
                <span class="setting-title">{t('settings.skip_anims_title')}</span>
                <span class="setting-desc">{t('settings.skip_anims_desc')}</span>
              </div>
              <label class="setting-toggle">
                <input
                  type="checkbox"
                  data-testid="setting-skip-anims"
                  checked={settings.skip_animations}
                  onChange={(e) => updateSetting('skip_animations', e.currentTarget.checked)}
                  class="checkbox-input"
                />
              </label>
            </div>
          </div>

          {/* ACCESSIBILITY SECTION */}
          <div class="settings-section">
            <h3 class="settings-section-title">
              <span>👓</span> {t('settings.section_accessibility')}
            </h3>

            {/* Increase hints font size */}
            <div class="setting-item">
              <div class="setting-info">
                <span class="setting-title">{t('settings.bigger_hints_title')}</span>
                <span class="setting-desc">{t('settings.bigger_hints_desc')}</span>
              </div>
              <label class="setting-toggle">
                <input
                  type="checkbox"
                  data-testid="setting-bigger-hints"
                  checked={settings.bigger_hints_font}
                  onChange={(e) => updateSetting('bigger_hints_font', e.currentTarget.checked)}
                  class="checkbox-input"
                />
              </label>
            </div>

            {/* Thicker walls */}
            <div class="setting-item">
              <div class="setting-info">
                <span class="setting-title">{t('settings.thicker_walls_title')}</span>
                <span class="setting-desc">{t('settings.thicker_walls_desc')}</span>
              </div>
              <label class="setting-toggle">
                <input
                  type="checkbox"
                  data-testid="setting-thicker-walls"
                  checked={settings.thicker_walls}
                  onChange={(e) => updateSetting('thicker_walls', e.currentTarget.checked)}
                  class="checkbox-input"
                />
              </label>
            </div>
          </div>

          {/* CONTROLS SECTION */}
          <div class="settings-section">
            <h3 class="settings-section-title">
              <span>🕹️</span> {t('settings.section_controls')}
            </h3>

            {/* Fill with drag */}
            <div class="setting-item">
              <div class="setting-info">
                <span class="setting-title">{t('settings.drag_content_title')}</span>
                <span class="setting-desc">{t('settings.drag_content_desc')}</span>
              </div>
              <label class="setting-toggle">
                <input
                  type="checkbox"
                  data-testid="setting-drag-content"
                  checked={settings.drag_content}
                  onChange={(e) => updateSetting('drag_content', e.currentTarget.checked)}
                  class="checkbox-input"
                />
              </label>
            </div>

            {/* Invert mouse buttons */}
            <div class="setting-item">
              <div class="setting-info">
                <span class="setting-title">{t('settings.invert_mouse_title')}</span>
                <span class="setting-desc">{t('settings.invert_mouse_desc')}</span>
              </div>
              <label class="setting-toggle">
                <input
                  type="checkbox"
                  data-testid="setting-invert-mouse"
                  checked={settings.invert_mouse}
                  onChange={(e) => updateSetting('invert_mouse', e.currentTarget.checked)}
                  class="checkbox-input"
                />
              </label>
            </div>

            {/* Auto-flood air */}
            <div class="setting-item">
              <div class="setting-info">
                <span class="setting-title">{t('settings.auto_flood_air_title')}</span>
                <span class="setting-desc">{t('settings.auto_flood_air_desc')}</span>
              </div>
              <label class="setting-toggle">
                <input
                  type="checkbox"
                  data-testid="auto-flood-air"
                  checked={settings.auto_flood_air}
                  onChange={(e) => updateSetting('auto_flood_air', e.currentTarget.checked)}
                  class="checkbox-input"
                />
              </label>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
