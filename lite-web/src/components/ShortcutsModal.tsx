import { h } from 'preact';
import { useTranslation } from '../i18n';

export interface ShortcutsModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export function ShortcutsModal({ isOpen, onClose }: ShortcutsModalProps) {
  const { t } = useTranslation();

  if (!isOpen) return null;

  return (
    <div
      data-testid="shortcuts-modal"
      class="modal-backdrop"
      onClick={onClose}
    >
      <div
        class="shortcuts-dialog"
        onClick={(e) => e.stopPropagation()}
      >
        <div class="shortcuts-header">
          <div class="flex items-center gap-2">
            <span class="text-xl">⌨️</span>
            <h2 class="shortcuts-title godot-text-outline">{t('shortcuts.title')}</h2>
          </div>
          <button
            data-testid="btn-close-shortcuts"
            onClick={onClose}
            class="shortcuts-close-btn"
            title={t('account.close')}
            aria-label={t('account.close')}
          >
            ✕
          </button>
        </div>

        <div class="shortcuts-content">
          {/* Mouse & Touch */}
          <div class="shortcut-section">
            <h3 class="shortcut-section-title">{t('shortcuts.sec_mouse')}</h3>
            <div class="shortcut-list">
              <div class="shortcut-item">
                <span class="shortcut-key">{t('shortcuts.tap_click')}</span>
                <span class="shortcut-desc">{t('shortcuts.tap_click_desc')}</span>
              </div>
              <div class="shortcut-item">
                <span class="shortcut-key">{t('shortcuts.right_click')}</span>
                <span class="shortcut-desc">{t('shortcuts.right_click_desc')}</span>
              </div>
              <div class="shortcut-item">
                <span class="shortcut-key">{t('shortcuts.middle_click')}</span>
                <span class="shortcut-desc">{t('shortcuts.middle_click_desc')}</span>
              </div>
              <div class="shortcut-item">
                <span class="shortcut-key">{t('shortcuts.drag')}</span>
                <span class="shortcut-desc">{t('shortcuts.drag_desc')}</span>
              </div>
            </div>
          </div>

          {/* Hover Keys */}
          <div class="shortcut-section">
            <h3 class="shortcut-section-title">{t('shortcuts.sec_hover')}</h3>
            <p class="shortcut-section-hint">{t('shortcuts.hover_hint')}</p>
            <div class="shortcut-list">
              <div class="shortcut-item">
                <div class="flex gap-1.5"><kbd class="kbd">W</kbd></div>
                <span class="shortcut-desc">{t('shortcuts.key_w_desc')}</span>
              </div>
              <div class="shortcut-item">
                <div class="flex gap-1.5"><kbd class="kbd">X</kbd></div>
                <span class="shortcut-desc">{t('shortcuts.key_x_desc')}</span>
              </div>
              <div class="shortcut-item">
                <div class="flex gap-1.5"><kbd class="kbd">B</kbd></div>
                <span class="shortcut-desc">{t('shortcuts.key_b_desc')}</span>
              </div>
              <div class="shortcut-item">
                <div class="flex gap-1.5"><kbd class="kbd">N</kbd></div>
                <span class="shortcut-desc">{t('shortcuts.key_n_desc')}</span>
              </div>
            </div>
          </div>

          {/* Tool Selection */}
          <div class="shortcut-section">
            <h3 class="shortcut-section-title">{t('shortcuts.sec_tools')}</h3>
            <div class="shortcut-list">
              <div class="shortcut-item">
                <div class="flex gap-1.5">
                  <kbd class="kbd">1</kbd>
                  <kbd class="kbd">2</kbd>
                  <kbd class="kbd">3</kbd>
                  <kbd class="kbd">4</kbd>
                </div>
                <span class="shortcut-desc">{t('shortcuts.key_14_desc')}</span>
              </div>
              <div class="shortcut-item">
                <div class="flex gap-1.5">
                  <kbd class="kbd">Tab</kbd> / <kbd class="kbd">Shift+Tab</kbd>
                </div>
                <span class="shortcut-desc">{t('shortcuts.key_tab_desc')}</span>
              </div>
            </div>
          </div>

          {/* Actions & Game */}
          <div class="shortcut-section">
            <h3 class="shortcut-section-title">{t('shortcuts.sec_actions')}</h3>
            <div class="shortcut-list">
              <div class="shortcut-item">
                <div class="flex gap-1.5">
                  <kbd class="kbd">Z</kbd> / <kbd class="kbd">Ctrl+Z</kbd>
                </div>
                <span class="shortcut-desc">{t('shortcuts.key_undo_desc')}</span>
              </div>
              <div class="shortcut-item">
                <div class="flex gap-1.5">
                  <kbd class="kbd">Y</kbd> / <kbd class="kbd">Ctrl+Y</kbd>
                </div>
                <span class="shortcut-desc">{t('shortcuts.key_redo_desc')}</span>
              </div>
              <div class="shortcut-item">
                <div class="flex gap-1.5"><kbd class="kbd">R</kbd></div>
                <span class="shortcut-desc">{t('shortcuts.key_restart_desc')}</span>
              </div>
              <div class="shortcut-item">
                <div class="flex gap-1.5"><kbd class="kbd">Esc</kbd> / <kbd class="kbd">?</kbd></div>
                <span class="shortcut-desc">{t('shortcuts.key_shortcuts_desc')}</span>
              </div>
            </div>
          </div>

          {/* Drawing / Marker Mode */}
          <div class="shortcut-section">
            <h3 class="shortcut-section-title">{t('shortcuts.sec_drawing')}</h3>
            <div class="shortcut-list">
              <div class="shortcut-item">
                <div class="flex gap-1.5"><kbd class="kbd">Space</kbd></div>
                <span class="shortcut-desc">{t('shortcuts.toggle_draw')}</span>
              </div>
              <div class="shortcut-item">
                <div class="flex gap-1.5"><kbd class="kbd">Tab</kbd> / <kbd class="kbd">E</kbd></div>
                <span class="shortcut-desc">{t('shortcuts.toggle_eraser')}</span>
              </div>
              <div class="shortcut-item">
                <span class="shortcut-key">{t('shortcuts.right_click')} & Drag</span>
                <span class="shortcut-desc">{t('shortcuts.opposite_tool')}</span>
              </div>
              <div class="shortcut-item">
                <div class="flex gap-1.5"><kbd class="kbd">B</kbd><kbd class="kbd">P</kbd></div>
                <span class="shortcut-desc">{t('shortcuts.pen_mode')}</span>
              </div>
              <div class="shortcut-item">
                <div class="flex gap-1.5"><kbd class="kbd">C</kbd></div>
                <span class="shortcut-desc">{t('shortcuts.cycle_color')}</span>
              </div>
              <div class="shortcut-item">
                <div class="flex gap-1.5"><kbd class="kbd">X</kbd><kbd class="kbd">Del</kbd></div>
                <span class="shortcut-desc">{t('shortcuts.clear_drawings')}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
