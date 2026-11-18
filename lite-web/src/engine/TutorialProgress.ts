// src/engine/TutorialProgress.ts
//
// The onboarding sequence for new players, built out of levels the campaign
// already ships, ordered so each one adds the next thing a daily can ask of
// you. Between them they cover every entry in ALL_MECHANICS, which is the same
// set the seven daily weekday themes draw from (Aquarium Sunday wants aquarium
// hints and diagonals, Secret Boat Tuesday wants boats, Hidden Thursday wants
// unknown hints, Freaky Friday wants all of it).
//
//   01/01  gravity, aquarium walls, and the row/column numbers
//   02/01  the {n} together and -n- separate decorators
//   03/04  diagonals (half waters) and the {?} / -?- unknown hints
//   04/01  boats
//   05/02  aquarium hints
//
// All five are solvable by pure deduction - verified with the solver, zero
// guesses. That is why the aquarium step is 05/02 and not the first level of
// that pack: 05/01 is unique but needs eight guesses, which is trial and error
// and no way to teach a rule.

import type { MechanicKey } from '../components/HelpModal';

export interface TutorialStep {
  /** Canonical level key, as LevelDatabase.normalizeLevelKey produces it. */
  levelKey: string;
  /** Which help-modal mechanics this step introduces. */
  mechanics: MechanicKey[];
}

export const TUTORIAL_STEPS: readonly TutorialStep[] = [
  { levelKey: 'Level 01/01', mechanics: ['aquariums', 'lineNumbers'] },
  { levelKey: 'Level 02/01', mechanics: ['togetherSeparate'] },
  { levelKey: 'Level 03/04', mechanics: ['diagonals', 'unknownHints'] },
  { levelKey: 'Level 04/01', mechanics: ['boats'] },
  { levelKey: 'Level 05/02', mechanics: ['aquariumHints'] },
];

export const TUTORIAL_DONE_STORAGE_KEY = 'liquidum_tutorial_done';

/** Only which steps are finished is kept. A half-played board is not worth
 *  restoring here - these are small levels meant to be done in one sitting. */
export function getTutorialDone(): Set<string> {
  const done = new Set<string>();
  if (typeof localStorage === 'undefined') return done;
  try {
    const raw = localStorage.getItem(TUTORIAL_DONE_STORAGE_KEY);
    if (!raw) return done;
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return done;
    for (const key of parsed) {
      // ignore anything that is not part of the sequence any more, so changing
      // the step list never resurrects a stale key
      if (typeof key === 'string' && isTutorialLevel(key)) {
        done.add(key);
      }
    }
  } catch {
    // unreadable or blocked storage just means "nothing done yet"
  }
  return done;
}

export function saveTutorialDone(done: Set<string>): void {
  if (typeof localStorage === 'undefined') return;
  try {
    localStorage.setItem(
      TUTORIAL_DONE_STORAGE_KEY,
      JSON.stringify(TUTORIAL_STEPS.filter(s => done.has(s.levelKey)).map(s => s.levelKey))
    );
  } catch {
    // storage full or blocked: progress is lost, the section still works
  }
}

/** Records a finished step and returns the new set. */
export function markTutorialDone(levelKey: string): Set<string> {
  const done = getTutorialDone();
  if (!isTutorialLevel(levelKey)) return done;
  done.add(levelKey);
  saveTutorialDone(done);
  return done;
}

export function isTutorialLevel(levelKey: string): boolean {
  return TUTORIAL_STEPS.some(s => s.levelKey === levelKey);
}

export function getTutorialStep(levelKey: string): TutorialStep | null {
  return TUTORIAL_STEPS.find(s => s.levelKey === levelKey) ?? null;
}

/** 1-based position in the sequence, or 0 when the level is not part of it. */
export function getTutorialStepNumber(levelKey: string): number {
  return TUTORIAL_STEPS.findIndex(s => s.levelKey === levelKey) + 1;
}

export function isTutorialComplete(done: Set<string> = getTutorialDone()): boolean {
  return TUTORIAL_STEPS.every(s => done.has(s.levelKey));
}

/** The first unfinished step, which is where the section should open. */
export function getNextTutorialStep(done: Set<string> = getTutorialDone()): TutorialStep | null {
  return TUTORIAL_STEPS.find(s => !done.has(s.levelKey)) ?? null;
}

/** The step after this one, for the "next" button on the win banner. */
export function getStepAfter(levelKey: string): TutorialStep | null {
  const idx = TUTORIAL_STEPS.findIndex(s => s.levelKey === levelKey);
  if (idx === -1 || idx + 1 >= TUTORIAL_STEPS.length) return null;
  return TUTORIAL_STEPS[idx + 1];
}
