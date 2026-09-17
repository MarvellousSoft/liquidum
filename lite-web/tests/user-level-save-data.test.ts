import { describe, test, expect, beforeEach } from 'vitest';
import {
  UserLevelSaveData,
  saveDailyLevelProgress,
  loadDailyLevelProgress,
  clearDailyLevelProgress,
  saveLevelProgress,
  loadLevelProgress,
  DAILY_SAVE_STORAGE_KEY,
} from '../src/engine/UserLevelSaveData';
import { GridImpl, PureCell } from '../src/engine/GridImpl';
import { GridExporter } from '../src/engine/GridExporter';
import { LoadMode } from '../src/engine/Grid';
import { Content } from '../src/model/GridData';

// In-memory mock storage
class MockStorage implements Storage {
  private store: Record<string, string> = {};

  get length(): number {
    return Object.keys(this.store).length;
  }

  clear(): void {
    this.store = {};
  }

  getItem(key: string): string | null {
    return this.store[key] ?? null;
  }

  key(index: number): string | null {
    return Object.keys(this.store)[index] ?? null;
  }

  removeItem(key: string): void {
    delete this.store[key];
  }

  setItem(key: string, value: string): void {
    this.store[key] = String(value);
  }
}

describe('UserLevelSaveData', () => {
  let mockStorage: MockStorage;

  beforeEach(() => {
    mockStorage = new MockStorage();
  });

  test('constructor and get_data conform to Godot UserLevelSaveData format', () => {
    const save = new UserLevelSaveData({ some: 'data' }, false, 2, 45.5);
    const data = save.get_data();

    expect(data.version).toBe(1);
    expect(data.grid_data).toEqual({ some: 'data' });
    expect(data.is_empty).toBe(false);
    expect(data.mistakes).toBe(2);
    expect(data.timer_secs).toBe(45.5);
    expect(data.best_mistakes).toBe(-1);
    expect(data.best_time_secs).toBe(-1.0);
    expect(save.is_completed()).toBe(false);
  });

  test('save_completion records best time and mistakes', () => {
    const save = new UserLevelSaveData({}, false, 3, 60.0);
    save.save_completion(3, 60.0);

    expect(save.is_completed()).toBe(true);
    expect(save.best_mistakes).toBe(3);
    expect(save.best_time_secs).toBe(60.0);

    // Complete again with better time and mistakes
    save.save_completion(1, 45.0);
    expect(save.best_mistakes).toBe(1);
    expect(save.best_time_secs).toBe(45.0);

    // Complete again with worse time and mistakes: best remains untouched
    save.save_completion(5, 75.0);
    expect(save.best_mistakes).toBe(1);
    expect(save.best_time_secs).toBe(45.0);
  });

  test('load_data deserializes valid dictionary', () => {
    const raw = {
      version: 1,
      grid_data: { foo: 'bar' },
      is_empty: true,
      mistakes: 4,
      timer_secs: 12.3,
      best_mistakes: 2,
      best_time_secs: 10.5,
    };

    const loaded = UserLevelSaveData.load_data(raw);
    expect(loaded).not.toBeNull();
    expect(loaded?.grid_data).toEqual({ foo: 'bar' });
    expect(loaded?.is_empty).toBe(true);
    expect(loaded?.mistakes).toBe(4);
    expect(loaded?.timer_secs).toBe(12.3);
    expect(loaded?.best_mistakes).toBe(2);
    expect(loaded?.best_time_secs).toBe(10.5);
    expect(loaded?.is_completed()).toBe(true);
  });

  test('saveDailyLevelProgress and loadDailyLevelProgress with matching date', () => {
    const save = new UserLevelSaveData({ cells: [] }, false, 1, 30.0);
    saveDailyLevelProgress('2026-09-17', save, mockStorage);

    const loaded = loadDailyLevelProgress('2026-09-17', mockStorage);
    expect(loaded).not.toBeNull();
    expect(loaded?.mistakes).toBe(1);
    expect(loaded?.timer_secs).toBe(30.0);
  });

  test('loadDailyLevelProgress discards progress if date does not match (e.g. tomorrow)', () => {
    const save = new UserLevelSaveData({ cells: [] }, false, 2, 45.0);
    saveDailyLevelProgress('2026-09-16', save, mockStorage);

    // Today is 2026-09-17, loading with today's date should discard yesterday's save
    const loaded = loadDailyLevelProgress('2026-09-17', mockStorage);
    expect(loaded).toBeNull();

    // Verify it was wiped from storage
    expect(mockStorage.getItem(DAILY_SAVE_STORAGE_KEY)).toBeNull();
  });

  test('clearDailyLevelProgress removes saved item', () => {
    const save = new UserLevelSaveData({}, false, 0, 10.0);
    saveDailyLevelProgress('2026-09-17', save, mockStorage);
    expect(mockStorage.getItem(DAILY_SAVE_STORAGE_KEY)).not.toBeNull();

    clearDailyLevelProgress(mockStorage);
    expect(mockStorage.getItem(DAILY_SAVE_STORAGE_KEY)).toBeNull();
  });

  test('saveLevelProgress and loadLevelProgress for test / campaign levels', () => {
    const save = new UserLevelSaveData({ test: 123 }, false, 0, 15.0);
    saveLevelProgress('Level 01/01', save, mockStorage);

    const loaded = loadLevelProgress('Level 01/01', mockStorage);
    expect(loaded).not.toBeNull();
    expect(loaded?.grid_data).toEqual({ test: 123 });
    expect(loaded?.timer_secs).toBe(15.0);
  });

  test('Grid state export and ContentOnly restoration parity', () => {
    const gridStr = `
....
....
....
L...
`;
    const engine = GridImpl.from_str(gridStr, LoadMode.SolutionNoClear);
    // Put water in (0, 0)
    const cell = engine.get_cell(0, 0) as any;
    cell.put_water(0, false);

    const exported = engine.export_data();
    const save = new UserLevelSaveData(exported, engine.is_empty(), 0, 5.0);

    // Create a fresh clean engine of the same level
    const freshEngine = GridImpl.from_str(gridStr, LoadMode.SolutionNoClear);
    for (let r = 0; r < freshEngine.rows(); r++) {
      for (let c = 0; c < freshEngine.cols(); c++) {
        const pure = freshEngine.pure_cells[r][c];
        pure.c_left = Content.Nothing;
        pure.c_right = Content.Nothing;
      }
    }
    expect(freshEngine.pure_cells[0][0].c_left).toBe(Content.Nothing);

    // Restore saved data into freshEngine with ContentOnly mode
    new GridExporter().load_data(freshEngine, save.grid_data, LoadMode.ContentOnly, PureCell);

    // Verify cell (0, 0) has restored water
    expect(freshEngine.pure_cells[0][0].c_left).toBe(Content.Water);
  });
});
