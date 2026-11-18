import { h } from 'preact';
import { useTranslation } from '../i18n';
import { useModalScrollLock } from '../utils/scrollLock';
import { ALL_MECHANICS } from './HelpModal';
import {
  TUTORIAL_STEPS,
  getNextTutorialStep,
  isTutorialComplete,
} from '../engine/TutorialProgress';

export interface TutorialSectionModalProps {
  isOpen: boolean;
  onClose: () => void;
  done: Set<string>;
  currentLevelKey: string;
  isPlayingTutorial: boolean;
  onSelectStep: (levelKey: string) => void;
  onPlayDaily: () => void;
  iconUrl: (icon: string) => string;
}

/**
 * The learn-to-play section: the ordered list of onboarding levels, which ones
 * are done, and what each one teaches. Finishing all of them means every
 * mechanic a daily can use has been seen at least once.
 */
export function TutorialSectionModal({
  isOpen,
  onClose,
  done,
  currentLevelKey,
  isPlayingTutorial,
  onSelectStep,
  onPlayDaily,
  iconUrl,
}: TutorialSectionModalProps) {
  useModalScrollLock(isOpen);
  const { t } = useTranslation();

  if (!isOpen) return null;

  const doneCount = TUTORIAL_STEPS.filter(s => done.has(s.levelKey)).length;
  const complete = isTutorialComplete(done);
  const next = getNextTutorialStep(done);

  return (
    <div
      data-testid="tutorial-modal"
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
        style={{ maxWidth: '480px' }}
      >
        <div class="shortcuts-header">
          <div class="flex items-center gap-2">
            <span class="text-xl" aria-hidden="true">🎓</span>
            <h2 class="shortcuts-title godot-text-outline">{t('tutorial.title')}</h2>
          </div>
          <button
            data-testid="btn-close-tutorial-modal"
            onClick={onClose}
            class="shortcuts-close-btn"
            title={t('account.close')}
            aria-label={t('account.close')}
          >
            ✕
          </button>
        </div>

        <div class="shortcuts-content">
          <p class="text-xs opacity-75 mb-1 text-[var(--game-mint)]">
            {t('tutorial.intro')}
          </p>
          <p
            class="text-xs mb-3 text-[var(--game-mint)]"
            data-testid="tutorial-progress"
          >
            {t('tutorial.progress', { done: doneCount, total: TUTORIAL_STEPS.length })}
          </p>

          <div class="flex flex-col gap-2">
            {TUTORIAL_STEPS.map((step, idx) => {
              const isDone = done.has(step.levelKey);
              const isCurrent = isPlayingTutorial && step.levelKey === currentLevelKey;
              const statusClass = isCurrent
                ? 'level-btn-current'
                : isDone
                ? 'level-btn-done'
                : 'level-btn-unsolved';
              const teaches = step.mechanics
                .map(key => {
                  const m = ALL_MECHANICS.find(x => x.key === key);
                  return m ? `${m.icon} ${t(`mechanics.${m.key}.name`, m.name)}` : key;
                })
                .join(' · ');
              return (
                <button
                  key={step.levelKey}
                  data-testid={`tutorial-step-${idx + 1}`}
                  onClick={() => {
                    onSelectStep(step.levelKey);
                    onClose();
                  }}
                  class={`level-btn ${statusClass} w-full justify-start text-left`}
                >
                  <span class="w-5 shrink-0 text-center">
                    {isDone ? (
                      <img
                        src={iconUrl('checkmark.png')}
                        class="w-3.5 h-3.5 object-contain inline-block"
                        alt={t('tutorial.done_alt')}
                      />
                    ) : (
                      idx + 1
                    )}
                  </span>
                  <span class="flex-1">{teaches}</span>
                </button>
              );
            })}
          </div>

          <p class="text-xs mt-3 text-[var(--game-mint)] opacity-75">
            {complete ? t('tutorial.ready') : t('tutorial.goal')}
          </p>
        </div>

        <div class="px-5 py-3 border-t border-[rgba(217,255,226,0.15)] bg-[rgba(0,9,36,0.2)] flex justify-between gap-2 shrink-0">
          <button
            data-testid="btn-tutorial-play-daily"
            class="btn-secondary text-xs px-4 py-1.5"
            onClick={() => {
              onPlayDaily();
              onClose();
            }}
          >
            {t('tutorial.play_daily')}
          </button>
          {next ? (
            <button
              data-testid="btn-tutorial-continue"
              class="btn-secondary text-xs px-4 py-1.5"
              onClick={() => {
                onSelectStep(next.levelKey);
                onClose();
              }}
            >
              {doneCount > 0 ? t('tutorial.continue') : t('tutorial.start')}
            </button>
          ) : (
            <button
              data-testid="btn-tutorial-close"
              class="btn-secondary text-xs px-4 py-1.5"
              onClick={onClose}
            >
              {t('account.close')}
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
