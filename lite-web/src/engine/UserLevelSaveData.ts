// src/engine/UserLevelSaveData.ts
// Parity port of project/game/file_manager/UserLevelSaveData.gd

export interface UserLevelSaveDataDict {
  version: number;
  grid_data: any;
  is_empty: boolean;
  mistakes: number;
  timer_secs: number;
  best_mistakes: number;
  best_time_secs: number;
}

export class UserLevelSaveData {
  static readonly VERSION = 1;

  grid_data: any;
  is_empty: boolean;
  mistakes: number;
  timer_secs: number;

  best_mistakes: number = -1;
  best_time_secs: number = -1.0;

  constructor(
    grid_data_: any,
    is_empty_: boolean,
    mistakes_: number,
    timer_secs_: number
  ) {
    this.grid_data = grid_data_;
    this.is_empty = is_empty_;
    this.mistakes = mistakes_;
    this.timer_secs = timer_secs_;
  }

  get_data(): UserLevelSaveDataDict {
    return {
      version: UserLevelSaveData.VERSION,
      grid_data: this.grid_data,
      is_empty: this.is_empty,
      mistakes: this.mistakes,
      timer_secs: this.timer_secs,
      best_mistakes: this.best_mistakes,
      best_time_secs: this.best_time_secs,
    };
  }

  is_solution_empty(): boolean {
    return this.is_empty;
  }

  is_completed(): boolean {
    return this.best_mistakes >= 0;
  }

  save_completion(mistakes_: number, time: number): void {
    this.mistakes = mistakes_;
    this.timer_secs = time;
    this.best_mistakes = this.best_mistakes === -1 ? mistakes_ : Math.min(this.best_mistakes, mistakes_);
    this.best_time_secs = this.best_time_secs === -1.0 ? time : Math.min(this.best_time_secs, time);
  }

  static load_data(data: any): UserLevelSaveData | null {
    if (!data) return null;
    if (data.version !== UserLevelSaveData.VERSION) {
      console.error(`Invalid version ${data.version}, expected ${UserLevelSaveData.VERSION}`);
    }
    const save = new UserLevelSaveData(
      data.grid_data || {},
      Boolean(data.is_empty),
      Number(data.mistakes) || 0,
      Number(data.timer_secs) || 0.0
    );
    save.best_mistakes = data.best_mistakes !== undefined ? Number(data.best_mistakes) : -1;
    save.best_time_secs = data.best_time_secs !== undefined ? Number(data.best_time_secs) : -1.0;
    return save;
  }
}

// Storage helpers for web persistence

export const DAILY_SAVE_STORAGE_KEY = 'liquidum_daily_level_save';
export const LEVEL_SAVE_STORAGE_PREFIX = 'liquidum_save_level_';

function getDefaultStorage(): Storage | null {
  if (typeof window !== 'undefined' && window.localStorage) {
    return window.localStorage;
  }
  return null;
}

/**
 * Saves daily level progress tagged with the level's date.
 */
export function saveDailyLevelProgress(
  date: string,
  save: UserLevelSaveData,
  storage: Storage | null = getDefaultStorage()
): void {
  if (!storage) return;
  try {
    const payload = {
      date,
      save_data: save.get_data(),
    };
    storage.setItem(DAILY_SAVE_STORAGE_KEY, JSON.stringify(payload));
  } catch (err) {
    console.warn("Failed to save daily level progress:", err);
  }
}

/**
 * Loads daily level progress for the specified target date.
 * If saved progress is from an older date (yesterday or earlier), it is discarded and null is returned.
 */
export function loadDailyLevelProgress(
  targetDate: string,
  storage: Storage | null = getDefaultStorage()
): UserLevelSaveData | null {
  if (!storage) return null;
  try {
    const raw = storage.getItem(DAILY_SAVE_STORAGE_KEY);
    if (!raw) return null;

    const parsed = JSON.parse(raw);
    if (!parsed || parsed.date !== targetDate) {
      // Outdated daily level progress (e.g. from yesterday) -> discard it
      storage.removeItem(DAILY_SAVE_STORAGE_KEY);
      return null;
    }

    return UserLevelSaveData.load_data(parsed.save_data);
  } catch {
    return null;
  }
}

/**
 * Clears saved daily level progress.
 */
export function clearDailyLevelProgress(storage: Storage | null = getDefaultStorage()): void {
  if (!storage) return;
  try {
    storage.removeItem(DAILY_SAVE_STORAGE_KEY);
  } catch {
    // ignore
  }
}

/**
 * Saves progress for a specific campaign / test level.
 */
export function saveLevelProgress(
  levelKey: string,
  save: UserLevelSaveData,
  storage: Storage | null = getDefaultStorage()
): void {
  if (!storage) return;
  try {
    storage.setItem(LEVEL_SAVE_STORAGE_PREFIX + levelKey, JSON.stringify(save.get_data()));
  } catch (err) {
    console.warn("Failed to save level progress:", err);
  }
}

/**
 * Loads progress for a specific campaign / test level.
 */
export function loadLevelProgress(
  levelKey: string,
  storage: Storage | null = getDefaultStorage()
): UserLevelSaveData | null {
  if (!storage) return null;
  try {
    const raw = storage.getItem(LEVEL_SAVE_STORAGE_PREFIX + levelKey);
    if (!raw) return null;
    return UserLevelSaveData.load_data(JSON.parse(raw));
  } catch {
    return null;
  }
}
