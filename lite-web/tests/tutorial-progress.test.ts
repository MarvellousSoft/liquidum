import { describe, it, expect, beforeEach } from 'vitest';
import {
  TUTORIAL_STEPS,
  TUTORIAL_DONE_STORAGE_KEY,
  getTutorialDone,
  saveTutorialDone,
  markTutorialDone,
  isTutorialLevel,
  getTutorialStep,
  getTutorialStepNumber,
  isTutorialComplete,
  getNextTutorialStep,
  getStepAfter,
} from '../src/engine/TutorialProgress';
import { ALL_MECHANICS, getActiveMechanicsForWeekday } from '../src/components/HelpModal';
import type { MechanicKey } from '../src/components/HelpModal';
import { normalizeLevelKey, loadLevelData } from '../src/engine/LevelDatabase';
import { GridImpl } from '../src/engine/GridImpl';
import { LoadMode } from '../src/engine/Grid';
import { SolverModel, SolveResult } from '../src/engine/Solver';

describe('onboarding sequence', () => {
  it('is short enough to finish in one sitting', () => {
    expect(TUTORIAL_STEPS.length).toBeGreaterThanOrEqual(3);
    expect(TUTORIAL_STEPS.length).toBeLessThanOrEqual(5);
  });

  it('uses levels that exist, with canonical keys and no repeats', async () => {
    const seen = new Set<string>();
    for (const step of TUTORIAL_STEPS) {
      expect(normalizeLevelKey(step.levelKey)?.key).toBe(step.levelKey);
      expect(seen.has(step.levelKey)).toBe(false);
      seen.add(step.levelKey);
      const data = await loadLevelData(step.levelKey);
      expect(data, `${step.levelKey} should load`).not.toBeNull();
      expect(data.grid_data).toBeTruthy();
    }
  });

  it('only names mechanics the help modal actually documents', () => {
    const known = new Set(ALL_MECHANICS.map(m => m.key));
    for (const step of TUTORIAL_STEPS) {
      expect(step.mechanics.length).toBeGreaterThan(0);
      for (const key of step.mechanics) {
        expect(known.has(key), `${key} is not a documented mechanic`).toBe(true);
      }
    }
  });

  // the point of the whole section: after it, no daily can show something new
  it('covers every mechanic any weekday daily can use', () => {
    const taught = new Set<MechanicKey>();
    for (const step of TUTORIAL_STEPS) {
      for (const key of step.mechanics) taught.add(key);
    }
    for (let weekday = 0; weekday < 7; weekday++) {
      for (const needed of getActiveMechanicsForWeekday(weekday)) {
        expect(
          taught.has(needed),
          `weekday ${weekday} needs "${needed}", which no onboarding step teaches`
        ).toBe(true);
      }
    }
  });

  it('introduces each mechanic exactly once, in order', () => {
    const seen = new Set<MechanicKey>();
    for (const step of TUTORIAL_STEPS) {
      for (const key of step.mechanics) {
        expect(seen.has(key), `${key} is introduced twice`).toBe(false);
        seen.add(key);
      }
    }
  });

  // a step that needs trial and error teaches nothing, so this is a hard rule
  it('every step is solvable by pure deduction, with no guessing', async () => {
    for (const step of TUTORIAL_STEPS) {
      const data = await loadLevelData(step.levelKey);
      // Testing does not store the solution, so the solver is not steered by it
      const grid = GridImpl.import_data(data.grid_data, LoadMode.Testing);
      grid.clear_content();
      const result = new SolverModel().full_solve(
        grid,
        Object.keys(SolverModel.STRATEGY_LIST),
        () => false
      );
      expect(
        SolveResult[result],
        `${step.levelKey} should need no guesses`
      ).toBe(SolveResult[SolveResult.SolvedUniqueNoGuess]);
    }
  }, 60000);
});

// same stand-in the other storage tests use (tests/settings-manager.test.ts):
// vitest runs in node, where localStorage does not exist
class MockStorage implements Storage {
  private store: Record<string, string> = {};
  get length(): number { return Object.keys(this.store).length; }
  clear(): void { this.store = {}; }
  getItem(key: string): string | null { return this.store[key] ?? null; }
  key(index: number): string | null { return Object.keys(this.store)[index] ?? null; }
  removeItem(key: string): void { delete this.store[key]; }
  setItem(key: string, value: string): void { this.store[key] = value; }
}

describe('onboarding progress', () => {
  beforeEach(() => {
    globalThis.localStorage = new MockStorage();
  });

  it('starts empty', () => {
    expect(getTutorialDone().size).toBe(0);
    expect(isTutorialComplete()).toBe(false);
    expect(getNextTutorialStep()?.levelKey).toBe(TUTORIAL_STEPS[0].levelKey);
  });

  it('remembers a finished step across reads', () => {
    const first = TUTORIAL_STEPS[0].levelKey;
    markTutorialDone(first);
    expect(getTutorialDone().has(first)).toBe(true);
    expect(getNextTutorialStep()?.levelKey).toBe(TUTORIAL_STEPS[1].levelKey);
  });

  it('ignores levels that are not part of the sequence', () => {
    markTutorialDone('Level 06/08');
    expect(getTutorialDone().size).toBe(0);
    expect(isTutorialLevel('Level 06/08')).toBe(false);
  });

  it('is complete only once every step is done', () => {
    for (const step of TUTORIAL_STEPS.slice(0, -1)) {
      markTutorialDone(step.levelKey);
    }
    expect(isTutorialComplete()).toBe(false);
    markTutorialDone(TUTORIAL_STEPS[TUTORIAL_STEPS.length - 1].levelKey);
    expect(isTutorialComplete()).toBe(true);
    expect(getNextTutorialStep()).toBeNull();
  });

  it('drops stored keys that are no longer steps', () => {
    localStorage.setItem(
      TUTORIAL_DONE_STORAGE_KEY,
      JSON.stringify([TUTORIAL_STEPS[0].levelKey, 'Level 99/99'])
    );
    const done = getTutorialDone();
    expect(done.size).toBe(1);
    expect(done.has(TUTORIAL_STEPS[0].levelKey)).toBe(true);
  });

  it('survives garbage in storage', () => {
    localStorage.setItem(TUTORIAL_DONE_STORAGE_KEY, 'not json at all');
    expect(getTutorialDone().size).toBe(0);
    localStorage.setItem(TUTORIAL_DONE_STORAGE_KEY, '{"a":1}');
    expect(getTutorialDone().size).toBe(0);
  });

  it('writes the steps back in sequence order', () => {
    saveTutorialDone(new Set([TUTORIAL_STEPS[2].levelKey, TUTORIAL_STEPS[0].levelKey]));
    expect(JSON.parse(localStorage.getItem(TUTORIAL_DONE_STORAGE_KEY)!)).toEqual([
      TUTORIAL_STEPS[0].levelKey,
      TUTORIAL_STEPS[2].levelKey,
    ]);
  });

  it('numbers and links the steps', () => {
    expect(getTutorialStepNumber(TUTORIAL_STEPS[0].levelKey)).toBe(1);
    expect(getTutorialStepNumber('Level 99/99')).toBe(0);
    expect(getTutorialStep(TUTORIAL_STEPS[1].levelKey)?.levelKey).toBe(TUTORIAL_STEPS[1].levelKey);
    expect(getStepAfter(TUTORIAL_STEPS[0].levelKey)?.levelKey).toBe(TUTORIAL_STEPS[1].levelKey);
    expect(getStepAfter(TUTORIAL_STEPS[TUTORIAL_STEPS.length - 1].levelKey)).toBeNull();
  });
});
