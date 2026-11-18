import { h } from 'preact';
import { useTranslation } from '../i18n';
import { useModalScrollLock } from '../utils/scrollLock';
import { ALL_MECHANICS, getActiveMechanicsForWeekday } from './HelpModal';
import { get_today_str } from '../engine/DailyLevel';
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
  /** Which day's level the badges refer to; defaults to today. */
  dailyDate?: string;
  onSelectStep: (levelKey: string) => void;
  onPlayDaily: () => void;
  onOpenHelp: () => void;
  iconUrl: (icon: string) => string;
}

/**
 * The learn-to-play section: the ordered list of tutorials, which ones are
 * done, and what each one teaches. Finishing all of them means every rule a
 * daily level can use has been seen at least once.
 *
 * The "in today's level" badge is the same one the help modal shows, driven by
 * the same getActiveMechanicsForWeekday, so a player can tell at a glance
 * which tutorials matter for the puzzle waiting for them.
 */
export function TutorialSectionModal({
  isOpen,
  onClose,
  done,
  currentLevelKey,
  isPlayingTutorial,
  dailyDate,
  onSelectStep,
  onPlayDaily,
  onOpenHelp,
  iconUrl,
}: TutorialSectionModalProps) {
  useModalScrollLock(isOpen);
  const { t } = useTranslation();

  if (!isOpen) return null;

  const dateStr = dailyDate || get_today_str();
  const [year, month, day] = dateStr.split('-').map(Number);
  const weekday = new Date(Date.UTC(year, month - 1, day)).getUTCDay();
  const activeMechanics = getActiveMechanicsForWeekday(weekday);

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
        style={{ maxWidth: '520px' }}
      >
        <div class="shortcuts-header">
          <div class="flex items-center gap-2">
            <span class="text-xl" aria-hidden="true">🎓</span>
            <h2 class="shortcuts-title godot-text-outline">{t('tutorial.title')}</h2>
          </div>
          <div class="flex items-center gap-2">
            <button
              data-testid="btn-tutorial-how-to-play"
              onClick={onOpenHelp}
              class="btn-secondary text-xs px-3 py-1"
              title={t('tutorial.how_to_play')}
            >
              ❓ {t('tutorial.how_to_play')}
            </button>
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
        </div>

        <div class="shortcuts-content">
          <p class="text-xs opacity-75 mb-1 text-[var(--game-mint)] leading-relaxed">
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
              const inToday = step.mechanics.some(key => activeMechanics.has(key));
              const statusClass = isCurrent
                ? 'level-btn-current'
                : isDone
                ? 'level-btn-done'
                : 'level-btn-unsolved';
              const labels = step.mechanics.map(key => {
                const m = ALL_MECHANICS.find(x => x.key === key);
                return m ? `${m.icon} ${t(`mechanics.${m.key}.name`, m.name)}` : key;
              });
              // the water counter is not one of ALL_MECHANICS, so it names itself
              if (step.teachesWaterCounter) {
                labels.push(`💧 ${t('tutorial.counter_title')}`);
              }
              const teaches = labels.join(' · ');
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
                  {inToday && (
                    <span
                      data-testid={`tutorial-badge-today-${idx + 1}`}
                      class="shrink-0 px-1.5 py-0.5 rounded text-[10px] font-bold tracking-wide uppercase bg-cyan-500/20 text-cyan-300 border border-cyan-400/50"
                    >
                      {t('help.in_todays_puzzle')}
                    </span>
                  )}
                </button>
              );
            })}
          </div>

          <p class="text-xs mt-3 text-[var(--game-mint)] opacity-75">
            {complete ? t('tutorial.ready') : t('tutorial.goal')}
          </p>
        </div>

        <div class="px-5 py-3 border-t border-[rgba(217,255,226,0.15)] bg-[rgba(0,9,36,0.2)] flex justify-between gap-2 shrink-0">
          {/* Leaving the section on purpose, so it is coloured like an exit
              rather than like the other actions in here. */}
          <button
            data-testid="btn-tutorial-play-daily"
            class="tutorial-skip-btn text-xs px-4 py-1.5"
            title={t('tutorial.play_daily_title')}
            onClick={() => {
              onPlayDaily();
              onClose();
            }}
          >
            {t('tutorial.play_daily')} ↪
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
