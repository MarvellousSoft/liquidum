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
import { parseGridData, Content } from '../src/model/GridData';
import { GridImpl } from '../src/engine/GridImpl';
import { LoadMode } from '../src/engine/Grid';
import { SolverModel, SolveResult } from '../src/engine/Solver';

/** Largest number of cells joined into one aquarium, read from the walls. */
function biggestAquarium(parsed: any): number {
  const rows = parsed.cells.length;
  const cols = rows > 0 ? parsed.cells[0].length : 0;
  const wallBottom = (i: number, j: number) =>
    i >= rows - 1 ? true : Boolean(parsed.wall_bottom?.[i]?.[j]);
  const wallRight = (i: number, j: number) =>
    j >= cols - 1 ? true : Boolean(parsed.wall_right?.[i]?.[j]);

  const seen = new Set<string>();
  let biggest = 0;
  for (let i = 0; i < rows; i++) {
    for (let j = 0; j < cols; j++) {
      if (seen.has(`${i},${j}`)) continue;
      const stack = [[i, j]];
      seen.add(`${i},${j}`);
      let size = 0;
      while (stack.length) {
        const [a, b] = stack.pop()!;
        size++;
        const neighbours: [number, number][] = [];
        if (!wallBottom(a, b)) neighbours.push([a + 1, b]);
        if (a > 0 && !wallBottom(a - 1, b)) neighbours.push([a - 1, b]);
        if (!wallRight(a, b)) neighbours.push([a, b + 1]);
        if (b > 0 && !wallRight(a, b - 1)) neighbours.push([a, b - 1]);
        for (const [x, y] of neighbours) {
          if (x < 0 || y < 0 || x >= rows || y >= cols) continue;
          if (seen.has(`${x},${y}`)) continue;
          seen.add(`${x},${y}`);
          stack.push([x, y]);
        }
      }
      biggest = Math.max(biggest, size);
    }
  }
  return biggest;
}

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

  it('teaches the controls on the very first tutorial and nowhere else', () => {
    expect(TUTORIAL_STEPS[0].teachesControls).toBe(true);
    for (const step of TUTORIAL_STEPS.slice(1)) {
      expect(step.teachesControls).toBeFalsy();
    }
  });

  // The first draft claimed level 01/01 taught gravity. It cannot: every cell
  // there is walled off on all four sides, so water never flows. A level only
  // teaches gravity if some aquarium is bigger than a single cell.
  it('only claims the aquariums rule on levels where water can actually flow', async () => {
    for (const step of TUTORIAL_STEPS) {
      if (!step.mechanics.includes('aquariums')) continue;
      const data = await loadLevelData(step.levelKey);
      const parsed = parseGridData(data);
      expect(
        biggestAquarium(parsed),
        `${step.levelKey} has only 1x1 aquariums, so it cannot show gravity`
      ).toBeGreaterThan(1);
    }
  });

  // the daily generator never places rock, so a tutorial showing some would be
  // introducing a thing the player will never meet again
  it('uses no level with rock cells in it', async () => {
    for (const step of TUTORIAL_STEPS) {
      const data = await loadLevelData(step.levelKey);
      const parsed = parseGridData(data);
      const rock = parsed.cells
        .flat()
        .filter((c: any) => c.c_left === Content.Block || c.c_right === Content.Block).length;
      expect(rock, `${step.levelKey} has ${rock} rock cell(s)`).toBe(0);
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
