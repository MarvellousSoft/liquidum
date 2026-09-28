import { h } from 'preact';
import { useEffect } from 'preact/hooks';
import { useTranslation } from '../i18n';
import { useModalScrollLock } from '../utils/scrollLock';

export interface LevelSelectModalProps {
  isOpen: boolean;
  onClose: () => void;
  levelKeys: string[];
  currentLevelKey: string;
  isDailyMode: boolean;
  completedLevels: Set<string>;
  onSelectLevel: (key: string) => void;
  iconUrl: (icon: string) => string;
}

export function LevelSelectModal({
  isOpen,
  onClose,
  levelKeys,
  currentLevelKey,
  isDailyMode,
  completedLevels,
  onSelectLevel,
  iconUrl,
}: LevelSelectModalProps) {
  useModalScrollLock(isOpen);
  const { t } = useTranslation();

  if (!isOpen) return null;

  return (
    <div
      data-testid="levels-modal"
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
        style={{ maxWidth: '440px' }}
      >
        <div class="shortcuts-header">
          <div class="flex items-center gap-2">
            <span class="text-xl">🧪</span>
            <h2 class="shortcuts-title godot-text-outline">{t('game.test_levels')}</h2>
          </div>
          <button
            data-testid="btn-close-levels-modal"
            onClick={onClose}
            class="shortcuts-close-btn"
            title={t('account.close')}
            aria-label={t('account.close')}
          >
            ✕
          </button>
        </div>

        <div class="shortcuts-content">
          <p class="text-xs opacity-75 mb-3 text-[var(--game-mint)]">
            {t('game.test_levels_desc')}
          </p>
          <div class="grid grid-cols-2 gap-2">
            {levelKeys.map((key) => {
              const isCurrent = !isDailyMode && key === currentLevelKey;
              const isDone = completedLevels.has(key);
              const statusClass = isCurrent
                ? 'level-btn-current'
                : isDone
                ? 'level-btn-done'
                : 'level-btn-unsolved';
              return (
                <button
                  key={key}
                  onClick={() => {
                    onSelectLevel(key);
                    onClose();
                  }}
                  class={`level-btn ${statusClass} justify-center w-full`}
                >
                  {isDone && (
                    <img
                      src={iconUrl('checkmark.png')}
                      class="w-3.5 h-3.5 object-contain"
                      alt="done"
                    />
                  )}
                  <span>{key}</span>
                </button>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}
