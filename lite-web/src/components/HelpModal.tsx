import { h } from 'preact';
import { get_today_str, WEEKDAY_INFO } from '../engine/DailyLevel';

export interface HelpModalProps {
  isOpen: boolean;
  onClose: () => void;
  dailyDate?: string;
  onOpenAccount?: () => void;
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
  description: string;
}

export const ALL_MECHANICS: MechanicInfo[] = [
  {
    key: 'aquariums',
    icon: '💧',
    name: 'Aquariums & Gravity',
    description:
      'Thick borders divide the grid into separate aquariums. You fill cells with water, which falls according to gravity.',
  },
  {
    key: 'lineNumbers',
    icon: '🔢',
    name: 'Row & Column Hints',
    description:
      'Numbers outside the grid indicate the exact amount of water cells required in that row or column.',
  },
  {
    key: 'boats',
    icon: '⛵',
    name: 'Boats',
    description:
      'Boats float on top of water. The cell directly below a boat must have water.',
  },
  {
    key: 'diagonals',
    icon: '〽️',
    name: 'Diagonals',
    description:
      'Diagonal walls split a cell into half-cells. Each filled half-cell counts as 0.5 waters.',
  },
  {
    key: 'aquariumHints',
    icon: '🐟',
    name: 'Aquarium Hints',
    description:
      'These tell you how many aquariums with a certain amount of water are present in the level.',
  },
  {
    key: 'unknownHints',
    icon: '❓',
    name: 'Unknown Hints (?)',
    description:
      'A question mark indicates a contiguous water group of unknown size (at least 1 cell).',
  },
  {
    key: 'togetherSeparate',
    icon: '↔️',
    name: 'Together & Separate Hints',
    description:
      "{N} indicates that the water in that row/column are contiguous.\n-N- indicates that they are not (there is at least one empty cell in the middle).",
  },
];

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

export function HelpModal({ isOpen, onClose, dailyDate, onOpenAccount }: HelpModalProps) {
  if (!isOpen) return null;

  const dateStr = dailyDate || get_today_str();
  const [year, month, day] = dateStr.split('-').map(Number);
  const weekday = new Date(Date.UTC(year, month - 1, day)).getUTCDay();
  const dayInfo = WEEKDAY_INFO[weekday] || WEEKDAY_INFO[1];
  const activeMechanics = getActiveMechanicsForWeekday(weekday);

  return (
    <div
      data-testid="help-modal"
      class="modal-backdrop"
      onClick={onClose}
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
            <h2 class="shortcuts-title godot-text-outline">How to Play</h2>
          </div>
          <button
            data-testid="btn-close-help"
            onClick={onClose}
            class="shortcuts-close-btn"
            title="Close (Esc)"
            aria-label="Close"
          >
            ✕
          </button>
        </div>

        {/* Content */}
        <div class="shortcuts-content overflow-y-auto space-y-4 pr-1">

          {/* Objective */}
          <div class="text-xs text-slate-300 leading-relaxed bg-slate-900/60 p-3 rounded-lg border border-slate-700/50">
            <span class="font-bold text-[var(--game-mint)]">Goal:</span> Fill cells with Water (💧) and Boats (⛵) according to row, column, and other hints without making mistakes. You can mark empty cells with Air (✕) if it helps.
          </div>

          {/* Today's theme summary banner */}
          <div class="space-y-2.5">
            <h3 class="text-xs font-bold uppercase tracking-wider text-slate-400">Today's Puzzle</h3>
            <div
              data-testid="today-theme-banner"
              class="p-3 rounded-lg border border-cyan-500/40 bg-cyan-950/30 flex items-start gap-2.5"
            >
              <span class="text-2xl shrink-0">{dayInfo.emoji}</span>
              <div class="text-xs">
                <div class="font-bold text-cyan-300 text-sm">{dayInfo.name}</div>
                <div class="text-slate-300 opacity-90 mt-0.5">{dayInfo.desc}</div>
              </div>
            </div>
          </div>

          {/* Mechanics Grid */}
          <div class="space-y-2.5">
            <h3 class="text-xs font-bold uppercase tracking-wider text-slate-400">Game Mechanics</h3>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-2.5">
              {ALL_MECHANICS.map((m) => {
                const isToday = activeMechanics.has(m.key);
                return (
                  <div
                    key={m.key}
                    data-testid={`mechanic-card-${m.key}`}
                    class={`p-3 rounded-lg border transition-colors flex flex-col justify-between ${isToday
                      ? 'border-cyan-400/80 bg-cyan-950/40 shadow-sm shadow-cyan-950'
                      : 'border-slate-800 bg-slate-900/40 opacity-85'
                      }`}
                  >
                    <div>
                      <div class="flex items-center justify-between gap-2 mb-1.5 flex-wrap">
                        <div class="flex items-center gap-1.5 font-bold text-sm text-slate-100">
                          <span>{m.icon}</span>
                          <span>{m.name}</span>
                        </div>
                        {isToday && (
                          <span
                            data-testid="badge-in-todays-puzzle"
                            class="px-1.5 py-0.5 rounded text-[10px] font-bold tracking-wide uppercase bg-cyan-500/20 text-cyan-300 border border-cyan-400/50"
                          >
                            In Today's Puzzle
                          </span>
                        )}
                      </div>
                      <p class="text-xs text-slate-300 leading-relaxed whitespace-pre-line">{m.description}</p>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Controls Summary */}
          <div class="pt-2 border-t border-slate-800">
            <h3 class="text-xs font-bold uppercase tracking-wider text-slate-400 mb-2">Controls</h3>
            <div class="grid grid-cols-2 sm:grid-cols-4 gap-2 text-xs">
              <div class="p-2 rounded bg-slate-900/60 border border-slate-800">
                <div class="font-semibold text-slate-200">Left Click / Tap</div>
                <div class="text-slate-400 text-[11px] mt-0.5">Place Water (💧)</div>
              </div>
              <div class="p-2 rounded bg-slate-900/60 border border-slate-800">
                <div class="font-semibold text-slate-200">Right Click</div>
                <div class="text-slate-400 text-[11px] mt-0.5">Place Air (✕)</div>
              </div>
              <div class="p-2 rounded bg-slate-900/60 border border-slate-800">
                <div class="font-semibold text-slate-200">Middle Click</div>
                <div class="text-slate-400 text-[11px] mt-0.5">Place Boat (⛵)</div>
              </div>
            </div>
          </div>

          {/* Account / Cross-device note */}
          <div
            data-testid="help-recovery-note"
            class="text-xs text-slate-300 leading-relaxed bg-slate-900/60 p-3 rounded-lg border border-slate-700/50"
          >
            <span class="font-bold text-[var(--game-mint)]">Note:</span> If you also play on Steam or are moving from another browser, copy its Account Recovery Key from Account Settings and restore it{' '}
            <button
              type="button"
              data-testid="link-open-account"
              onClick={() => {
                onClose();
                onOpenAccount?.();
              }}
              class="text-cyan-300 hover:text-white underline font-semibold cursor-pointer inline p-0 bg-transparent border-none text-xs"
            >
              here
            </button>{' '}
            to keep your leaderboard presence and streak.
          </div>
        </div>

        {/* Footer */}
        <div class="pt-3 mt-3 border-t border-slate-800 flex justify-end shrink-0">
          <button
            data-testid="btn-help-got-it"
            onClick={onClose}
            class="px-4 py-1.5 rounded-lg bg-cyan-600 hover:bg-cyan-500 text-white text-xs font-bold transition shadow"
          >
            Got it
          </button>
        </div>
      </div>
    </div>
  );
}
