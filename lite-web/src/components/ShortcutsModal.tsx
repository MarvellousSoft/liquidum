import { h } from 'preact';
import { useState, useEffect } from 'preact/hooks';
import { useTranslation } from '../i18n';
import { lockBodyScroll, unlockBodyScroll } from '../utils/scrollLock';

export interface ShortcutsModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export function ShortcutsModal({ isOpen, onClose }: ShortcutsModalProps) {
  const { t } = useTranslation();

  const isMobileOrTouch = () => {
    if (typeof window === 'undefined') return false;
    return window.matchMedia('(max-width: 768px), (pointer: coarse)').matches;
  };

  const [viewMode, setViewMode] = useState<'touch' | 'keyboard'>(() => {
    return isMobileOrTouch() ? 'touch' : 'keyboard';
  });

  useEffect(() => {
    if (isOpen) {
      lockBodyScroll();
      setViewMode(isMobileOrTouch() ? 'touch' : 'keyboard');
      return () => {
        unlockBodyScroll();
      };
    }
  }, [isOpen]);

  if (!isOpen) return null;

  return (
    <div
      data-testid="shortcuts-modal"
      class="modal-backdrop"
      onClick={onClose}
      onTouchMove={(e) => {
        if (e.target === e.currentTarget) {
          e.preventDefault();
        }
      }}
    >
      <div
        class="shortcuts-dialog"
        onClick={(e) => e.stopPropagation()}
      >
        <div class="shortcuts-header flex flex-wrap items-center justify-between gap-2">
          <div class="flex items-center gap-2">
            <span class="text-xl">{viewMode === 'touch' ? '👆' : '⌨️'}</span>
            <h2 class="shortcuts-title godot-text-outline">
              {viewMode === 'touch' ? t('shortcuts.touch_title') : t('shortcuts.title')}
            </h2>
          </div>

          <div class="flex items-center gap-2">
            {/* View Mode Toggle Buttons */}
            <div class="flex items-center bg-[rgba(0,9,36,0.4)] p-0.5 rounded-lg border border-[rgba(217,255,226,0.2)]">
              <button
                type="button"
                data-testid="tab-shortcuts-touch"
                class={`px-2.5 py-1 text-xs rounded-md font-medium transition cursor-pointer ${viewMode === 'touch'
                  ? 'bg-[var(--game-teal)] text-white shadow font-bold'
                  : 'text-[rgba(217,255,226,0.7)] hover:text-white'
                  }`}
                onClick={() => setViewMode('touch')}
              >
                📱 {t('shortcuts.tab_touch')}
              </button>
              <button
                type="button"
                data-testid="tab-shortcuts-keyboard"
                class={`px-2.5 py-1 text-xs rounded-md font-medium transition cursor-pointer ${viewMode === 'keyboard'
                  ? 'bg-[var(--game-teal)] text-white shadow font-bold'
                  : 'text-[rgba(217,255,226,0.7)] hover:text-white'
                  }`}
                onClick={() => setViewMode('keyboard')}
              >
                ⌨️ {t('shortcuts.tab_keyboard')}
              </button>
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
        </div>

        {viewMode === 'touch' ? (
          <div class="shortcuts-content overflow-y-auto overscroll-contain" data-testid="shortcuts-touch-content">
            {/* Board Gestures */}
            <div class="shortcut-section">
              <h3 class="shortcut-section-title">{t('shortcuts.sec_touch_gestures')}</h3>
              <div class="shortcut-list">
                <div class="shortcut-item">
                  <span class="shortcut-key">{t('shortcuts.touch_tap')}</span>
                  <span class="shortcut-desc">{t('shortcuts.tap_click_desc')}</span>
                </div>
                <div class="shortcut-item">
                  <span class="shortcut-key">{t('shortcuts.touch_hold')}</span>
                  <span class="shortcut-desc">{t('shortcuts.touch_hold_desc')}</span>
                </div>
                <div class="shortcut-item">
                  <span class="shortcut-key">{t('shortcuts.touch_drag')}</span>
                  <span class="shortcut-desc">{t('shortcuts.drag_desc')}</span>
                </div>
                <div class="shortcut-item">
                  <span class="shortcut-key">{t('shortcuts.touch_hints')}</span>
                  <span class="shortcut-desc">{t('shortcuts.touch_hints_desc')}</span>
                </div>
                <div class="shortcut-item">
                  <span class="shortcut-key">{t('shortcuts.hold_hints')}</span>
                  <span class="shortcut-desc">{t('shortcuts.right_click_hint_desc')}</span>
                </div>
              </div>
            </div>

            {/* Toolbar Controls */}
            <div class="shortcut-section">
              <h3 class="shortcut-section-title">{t('shortcuts.sec_touch_tools')}</h3>
              <div class="shortcut-list">
                <div class="shortcut-item">
                  <span class="shortcut-key">{t('shortcuts.touch_tools')}</span>
                  <span class="shortcut-desc">{t('shortcuts.touch_tools_desc')}</span>
                </div>
                <div class="shortcut-item">
                  <span class="shortcut-key">{t('shortcuts.touch_undo')}</span>
                  <span class="shortcut-desc">{t('shortcuts.touch_undo_desc')}</span>
                </div>
                <div class="shortcut-item">
                  <span class="shortcut-key">{t('shortcuts.touch_restart')}</span>
                  <span class="shortcut-desc">{t('shortcuts.touch_restart_desc')}</span>
                </div>
              </div>
            </div>

            {/* Drawing & Notes Mode */}
            <div class="shortcut-section">
              <h3 class="shortcut-section-title">{t('shortcuts.sec_touch_drawing')}</h3>
              <div class="shortcut-list">
                <div class="shortcut-item">
                  <span class="shortcut-key">{t('shortcuts.touch_pen')}</span>
                  <span class="shortcut-desc">{t('shortcuts.touch_pen_desc')}</span>
                </div>
                <div class="shortcut-item">
                  <span class="shortcut-key">{t('shortcuts.touch_eraser')}</span>
                  <span class="shortcut-desc">{t('shortcuts.touch_eraser_desc')}</span>
                </div>
                <div class="shortcut-item">
                  <span class="shortcut-key">{t('shortcuts.touch_color')}</span>
                  <span class="shortcut-desc">{t('shortcuts.touch_color_desc')}</span>
                </div>
                <div class="shortcut-item">
                  <span class="shortcut-key">{t('shortcuts.touch_clear')}</span>
                  <span class="shortcut-desc">{t('shortcuts.touch_clear_desc')}</span>
                </div>
              </div>
            </div>
          </div>
        ) : (
          <div class="shortcuts-content overflow-y-auto overscroll-contain" data-testid="shortcuts-keyboard-content">
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
                <div class="shortcut-item">
                  <span class="shortcut-key">{t('shortcuts.right_click_hint')}</span>
                  <span class="shortcut-desc">{t('shortcuts.right_click_hint_desc')}</span>
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
        )}
      </div>
    </div>
  );
}
