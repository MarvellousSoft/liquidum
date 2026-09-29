import { h } from 'preact';
import type { VNode } from 'preact';
import { useEffect } from 'preact/hooks';
import { get_today_str, WEEKDAY_INFO } from '../engine/DailyLevel';
import { useTranslation } from '../i18n';
import { useModalScrollLock } from '../utils/scrollLock';
import { TutorialGrid } from './TutorialGrid';

export interface HelpModalProps {
  isOpen: boolean;
  onClose: () => void;
  dailyDate?: string;
  onOpenAccount?: () => void;
  onOpenControls?: () => void;
}

export type MechanicKey =
  | 'aquariums'
  | 'lineNumbers'
  | 'boats'
  | 'diagonals'
  | 'aquariumHints'
  | 'unknownHints'
  | 'togetherSeparate';

export interface MechanicInfo {
  key: MechanicKey;
  icon: string;
  name: string;
  tutorial: VNode;
}

export const ALL_MECHANICS: MechanicInfo[] = [
  {
    key: 'aquariums',
    icon: '💧',
    name: 'Aquariums & Gravity',
    tutorial: (
      <div class="flex flex-row gap-4">
        <TutorialGrid cells={[['empty'], ['water']]} status="valid" isRowHint={false} iconPosition="bottom" />
        <TutorialGrid cells={[['water'], ['empty']]} status="invalid" isRowHint={false} iconPosition="bottom" />

        <TutorialGrid
          cells={[['empty', 'water'], ['water', 'water']]}
          status="invalid"
          isRowHint={false}
          iconPosition="bottom"
          wallBottom={[[false, false], [false, false]]}
          wallRight={[[false, false], [false, false]]}
        />
        <TutorialGrid
          cells={[['empty', 'water'], ['water', 'water']]}
          status="valid"
          isRowHint={false}
          iconPosition="bottom"
          wallBottom={[[true]]}
          wallRight={[[true]]}
        />
      </div>
    )
  },
  {
    key: 'lineNumbers',
    icon: '🔢',
    name: 'Row & Column Hints',
    tutorial: (
      <div class="flex flex-col gap-2">
        <TutorialGrid
          cells={[['water', 'empty', 'water', 'water', 'empty']]}
          hints={['3']}
          status="valid"
          wallRight={[[true, true, false, true, true]]}
        />
        <TutorialGrid
          cells={[['empty', 'water', 'empty', 'empty', 'empty']]}
          hints={['2']}
          status="invalid"
          wallRight={[[true, true, true, false, false]]}
        />
      </div>
    )
  },
  {
    key: 'boats',
    icon: '⛵',
    name: 'Boats',
    tutorial: (
      <div class="flex flex-row gap-4">
        <TutorialGrid cells={[['boat'], ['water']]} status="valid" isRowHint={false} iconPosition="bottom" />
        <TutorialGrid cells={[['boat'], ['empty']]} status="invalid" isRowHint={false} iconPosition="bottom" />
        <TutorialGrid cells={[['boat'], ['water']]} status="invalid" wallBottom={[[true]]} isRowHint={false} iconPosition="bottom" />

      </div>
    )
  },
  {
    key: 'diagonals',
    icon: '〽️',
    name: 'Diagonals',
    tutorial: (
      <div class="flex flex-row flex-wrap justify-center gap-4">
        <TutorialGrid cells={[['water-diag-inc', 'water-diag-dec']]} hints={['1']} status="valid" />
        <TutorialGrid cells={[['water-diag-inc-top', 'water-diag-dec-top']]} hints={['1']} status="valid" />
        <TutorialGrid cells={[['water-diag-inc-top', 'empty']]} hints={['1']} status="invalid" />
        <TutorialGrid cells={[['water-diag-inc', 'water']]} hints={['1.5']} status="valid" />

      </div>
    )
  },
  {
    key: 'togetherSeparate',
    icon: '↔️',
    name: 'Together & Separate Hints',
    tutorial: (
      <div class="flex flex-col gap-2">
        <TutorialGrid cells={[['empty', 'water', 'water', 'water', 'empty']]} hints={['{3}']} status="valid" wallRight={[[true, false, true, true, false]]} />
        <TutorialGrid cells={[['water', 'empty', 'empty', 'water', 'water']]} hints={['{3}']} status="invalid" wallRight={[[true, false, true, false, false]]} />
        <TutorialGrid cells={[['water', 'empty', 'water', 'water', 'empty']]} hints={['-3-']} status="valid" wallRight={[[true, true, true, true, false]]} />
      </div>
    )
  },
  {
    key: 'unknownHints',
    icon: '❓',
    name: 'Unknown Hints (?)',
    tutorial: (
      <div class="flex flex-col gap-2">
        <TutorialGrid cells={[['empty', 'water', 'empty']]} hints={['?']} status="valid" wallRight={[[true, true, false]]} />
        <TutorialGrid cells={[['empty', 'empty', 'empty', 'empty']]} hints={['{?}']} status="invalid" wallRight={[[true, true, false, false]]} />
        <TutorialGrid cells={[['water', 'water', 'empty', 'empty']]} hints={['{?}']} status="valid" wallRight={[[true, true, false, false]]} />
        <TutorialGrid cells={[['water', 'empty', 'empty', 'water']]} hints={['{?}']} status="invalid" wallRight={[[true, false, true, false]]} />

      </div>
    )
  },
  {
    key: 'aquariumHints',
    icon: '🐟',
    name: 'Aquarium Hints',
    tutorial: (
      <div class="flex flex-col gap-4">
        <div class="flex flex-row items-center gap-4">
          <div class="aquarium-card aquarium-card-satisfied shrink-0">
            <div class="aq-tank"><div class="aq-tank-water"></div><span class="aq-tank-size">3</span></div>
            <span class="aq-tank-count">1 / 1</span>
          </div>
          <TutorialGrid
            cells={[['water', 'water', 'water'], ['water', 'empty', 'empty']]}
            status="valid"
            isRowHint={false}
            iconPosition="right"
            wallBottom={[[true, true, true], [false, false, false]]}
            wallRight={[[false, false, false], [true, false, false]]}
          />
        </div>
        <div class="flex flex-row items-center gap-4">
          <div class="aquarium-card aquarium-card-over shrink-0">
            <div class="aq-tank"><div class="aq-tank-water"></div><span class="aq-tank-size">3</span></div>
            <span class="aq-tank-count">2 / 1</span>
          </div>
          <TutorialGrid
            cells={[['water', 'water', 'water'], ['water', 'water', 'water']]}
            status="invalid"
            isRowHint={false}
            iconPosition="right"
            wallBottom={[[true, true, true], [false, false, false]]}
          />
        </div>
      </div>
    )
  }
];

const WEEKDAY_KEYS = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'] as const;

/**
 * Determines which mechanics are active on a given weekday based on the daily theme.
 */
export function getActiveMechanicsForWeekday(weekday: number): Set<MechanicKey> {
  // Aquariums & Row/Col numbers are base rules present in every puzzle
  const active = new Set<MechanicKey>(['aquariums', 'lineNumbers']);

  switch (weekday) {
    case 0: // Aquarium Sunday: Diagonals and many aquarium hints visible
      active.add('diagonals');
      active.add('aquariumHints');
      break;
    case 1: // Basic Monday: No special rules
      break;
    case 2: // Secret Boat Tuesday: Boats have hidden hints
      active.add('boats');
      active.add('unknownHints');
      break;
    case 3: // Diagonal Wednesday: Diagonals and no hidden hints
      active.add('diagonals');
      break;
    case 4: // Hidden Thursday: Hidden water hints, plus boats
      active.add('boats');
      active.add('unknownHints');
      break;
    case 5: // Freaky Friday: Every rule, everywhere, all at once
      active.add('boats');
      active.add('diagonals');
      active.add('aquariumHints');
      active.add('unknownHints');
      active.add('togetherSeparate');
      break;
    case 6: // One Row Saturday: Only one row hint is visible
      break;
  }

  return active;
}

export function HelpModal({ isOpen, onClose, dailyDate, onOpenAccount, onOpenControls }: HelpModalProps) {
  useModalScrollLock(isOpen);

  if (!isOpen) return null;

  const { t } = useTranslation();
  const dateStr = dailyDate || get_today_str();
  const [year, month, day] = dateStr.split('-').map(Number);
  const weekday = new Date(Date.UTC(year, month - 1, day)).getUTCDay();
  const dayInfo = WEEKDAY_INFO[weekday] || WEEKDAY_INFO[1];
  const dayKey = WEEKDAY_KEYS[weekday] || 'mon';
  const activeMechanics = getActiveMechanicsForWeekday(weekday);

  return (
    <div
      data-testid="help-modal"
      class="modal-backdrop"
      onClick={onClose}
      onTouchMove={(e) => {
        if (e.target === e.currentTarget) {
          e.preventDefault();
        }
      }}
    >
      <div
        class="shortcuts-dialog max-w-2xl max-h-[85vh] flex flex-col"
        onClick={(e) => e.stopPropagation()}
        style={{ maxWidth: '680px' }}
      >
        {/* Header */}
        <div class="shortcuts-header shrink-0">
          <div class="flex items-center gap-2">
            <span class="text-xl">❓</span>
            <h2 class="shortcuts-title godot-text-outline">{t('help.title')}</h2>
          </div>
          <button
            data-testid="btn-close-help"
            onClick={onClose}
            class="shortcuts-close-btn"
            title={t('help.close_esc')}
            aria-label={t('help.close')}
          >
            ✕
          </button>
        </div>

        {/* Content */}
        <div class="shortcuts-content overflow-y-auto space-y-4 pr-1">

          {/* Objective */}
          <div class="text-xs text-slate-500 dark:text-slate-300 leading-relaxed p-3 rounded-lg" style={{ backgroundColor: 'var(--cell-bg)', border: '1px solid var(--cell-border)' }}>
            <span class="font-bold text-[var(--game-mint)]">{t('help.goal_label')}</span> {t('help.goal_text')}
          </div>

          {/* Today's theme summary banner */}
          <div class="space-y-2.5">
            <h3 class="text-xs font-bold uppercase tracking-wider text-slate-400">{t('help.todays_puzzle')}</h3>
            <div
              data-testid="today-theme-banner"
              class="p-3 rounded-lg flex items-start gap-2.5"
              style={{ backgroundColor: 'var(--cell-bg)', border: '1px solid var(--cell-border)' }}
            >
              <span class="text-2xl shrink-0">{dayInfo.emoji}</span>
              <div class="text-xs">
                <div class="font-bold text-cyan-300 text-sm">{t(`daily_theme.${dayKey}.name`, dayInfo.name)}</div>
                <div class="text-slate-300 opacity-90 mt-0.5">{t(`daily_theme.${dayKey}.desc`, dayInfo.desc)}</div>
              </div>
            </div>
          </div>

          {/* Mechanics Grid */}
          <div class="space-y-2.5">
            <h3 class="text-xs font-bold uppercase tracking-wider text-slate-400">{t('help.game_mechanics')}</h3>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-2.5">
              {ALL_MECHANICS.map((m) => {
                const isToday = activeMechanics.has(m.key);
                return (
                  <div
                    key={m.key}
                    data-testid={`mechanic-card-${m.key}`}
                    class={`p-3 rounded-lg transition-colors flex flex-col justify-between`}
                    style={{
                      backgroundColor: isToday ? 'var(--cell-bg)' : 'transparent',
                      border: `1px solid ${isToday ? 'var(--stat-satisfied)' : 'var(--cell-border)'}`,
                      opacity: isToday ? 1 : 0.85
                    }}
                  >
                    <div class="flex flex-col gap-3 h-full">
                      <div>
                        <div class="flex items-center justify-between gap-2 mb-1.5 flex-wrap">
                          <div class="flex items-center gap-1.5 font-bold text-sm text-slate-100">
                            <span>{m.icon}</span>
                            <span>{t(`mechanics.${m.key}.name`, m.name)}</span>
                          </div>
                          {isToday && (
                            <span
                              data-testid="badge-in-todays-puzzle"
                              class="px-1.5 py-0.5 rounded text-[10px] font-bold tracking-wide uppercase bg-cyan-500/20 text-cyan-300 border border-cyan-400/50"
                            >
                              {t('help.in_todays_puzzle')}
                            </span>
                          )}
                        </div>
                        <p class="text-xs text-slate-300 leading-relaxed whitespace-pre-line">{t(`mechanics.${m.key}.desc`)}</p>
                      </div>
                      <div
                        class="mt-auto flex justify-center rounded-lg p-2 shadow-inner"
                        style={{ backgroundColor: 'var(--cell-bg)', borderColor: 'var(--cell-border)', borderWidth: '1px' }}
                      >
                        {m.tutorial}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Controls Summary */}
          <div class="pt-2 border-t border-slate-800">
            <h3 class="text-xs font-bold uppercase tracking-wider text-slate-400 mb-2">{t('help.controls')}</h3>
            <div class="grid grid-cols-2 sm:grid-cols-4 gap-2 text-xs">
              <div class="p-2 rounded" style={{ backgroundColor: 'var(--cell-bg)', border: '1px solid var(--cell-border)' }}>
                <div class="font-semibold text-slate-700 dark:text-slate-200">{t('help.ctrl_left')}</div>
                <div class="text-slate-500 dark:text-slate-400 text-[11px] mt-0.5">{t('help.ctrl_left_desc')}</div>
              </div>
              <div class="p-2 rounded" style={{ backgroundColor: 'var(--cell-bg)', border: '1px solid var(--cell-border)' }}>
                <div class="font-semibold text-slate-700 dark:text-slate-200">{t('help.ctrl_right')}</div>
                <div class="text-slate-500 dark:text-slate-400 text-[11px] mt-0.5">{t('help.ctrl_right_desc')}</div>
              </div>
              <div class="p-2 rounded" style={{ backgroundColor: 'var(--cell-bg)', border: '1px solid var(--cell-border)' }}>
                <div class="font-semibold text-slate-700 dark:text-slate-200">{t('help.ctrl_mid')}</div>
                <div class="text-slate-500 dark:text-slate-400 text-[11px] mt-0.5">{t('help.ctrl_mid_desc')}</div>
              </div>
              {onOpenControls && (
                <button
                  type="button"
                  data-testid="card-open-controls"
                  onClick={() => {
                    onClose();
                    onOpenControls();
                  }}
                  class="p-2 rounded hover:brightness-110 transition flex flex-col justify-center items-start text-left cursor-pointer group"
                  style={{ backgroundColor: 'var(--cell-bg)', border: '1px solid var(--stat-satisfied)' }}
                >
                  <div class="font-semibold flex items-center gap-1" style={{ color: 'var(--stat-satisfied)' }}>
                    <span class="underline group-hover:text-white">{t('help.view_controls')}</span>
                    <span class="group-hover:translate-x-0.5 transition-transform group-hover:text-white">→</span>
                  </div>
                  <div class="text-slate-500 dark:text-slate-400 text-[11px] mt-0.5">{t('help.view_controls_desc')}</div>
                </button>
              )}
            </div>
          </div>

          {/* Account / Cross-device note */}
          <div
            data-testid="help-recovery-note"
            class="text-xs text-slate-300 leading-relaxed bg-slate-900/60 p-3 rounded-lg border border-slate-700/50"
          >
            <span class="font-bold text-[var(--game-mint)]">{t('help.note_label')}</span> {t('help.recovery_note_before')}{' '}
            <button
              type="button"
              data-testid="link-open-account"
              onClick={() => {
                onClose();
                onOpenAccount?.();
              }}
              class="text-cyan-300 hover:text-white underline font-semibold cursor-pointer inline p-0 bg-transparent border-none text-xs"
            >
              {t('help.recovery_note_link')}
            </button>{' '}
            {t('help.recovery_note_after')}
          </div>
        </div>

        {/* Footer */}
        <div class="px-5 py-3 border-t border-[rgba(217,255,226,0.15)] bg-[rgba(0,9,36,0.2)] flex justify-end shrink-0">
          <button
            data-testid="btn-help-close"
            class="btn-secondary text-xs px-4 py-1.5"
            onClick={onClose}
          >
            {t("account.close")}
          </button>
        </div>
      </div>
    </div>
  );
}
