// src/engine/StreakManager.ts
import { get_today_str, get_yesterday_str } from './DailyLevel';

export interface StreakData {
  currentStreak: number;
  bestStreak: number;
  lastCompletedDay: string | null;
}

export interface RecordCompletionResult {
  currentStreak: number;
  bestStreak: number;
  streakIncreased: boolean;
  streakBroken: boolean;
  isEligibleToday: boolean;
}

export const STREAK_STORAGE_KEY = 'liquidum_daily_streak_data';
export const STREAK_MAX_MISTAKES = 2;

function getDefaultStorage(): Storage | null {
  if (typeof window !== 'undefined' && window.localStorage) {
    return window.localStorage;
  }
  return null;
}

/**
 * Retrieves the current streak data.
 * If the user's last completed day was before yesterday UTC, the current streak is automatically reset to 0.
 */
export function getStreakData(storage: Storage | null = getDefaultStorage()): StreakData {
  const defaultData: StreakData = {
    currentStreak: 0,
    bestStreak: 0,
    lastCompletedDay: null,
  };

  if (!storage) return defaultData;

  try {
    const raw = storage.getItem(STREAK_STORAGE_KEY);
    if (!raw) return defaultData;

    const parsed = JSON.parse(raw);
    const data: StreakData = {
      currentStreak: Number(parsed.currentStreak) || 0,
      bestStreak: Number(parsed.bestStreak) || 0,
      lastCompletedDay: typeof parsed.lastCompletedDay === 'string' ? parsed.lastCompletedDay : null,
    };

    // If streak is active, check if user missed a day
    if (data.currentStreak > 0 && data.lastCompletedDay) {
      const today = get_today_str();
      const yesterday = get_yesterday_str();
      if (data.lastCompletedDay !== today && data.lastCompletedDay !== yesterday) {
        data.currentStreak = 0;
        saveStreakData(data, storage);
      }
    }

    return data;
  } catch {
    return defaultData;
  }
}

/**
 * Saves streak data to storage.
 */
export function saveStreakData(data: StreakData, storage: Storage | null = getDefaultStorage()): void {
  if (!storage) return;
  try {
    storage.setItem(STREAK_STORAGE_KEY, JSON.stringify(data));
  } catch (e) {
    console.warn("Failed to persist streak data:", e);
  }
}

/**
 * Records completion of a daily puzzle.
 * - Only counts for today's daily puzzle (UTC).
 * - Does not double-count if already completed today.
 * - Parity with Godot: if mistakes <= 2, streak increments. If mistakes > 2, streak resets to 0.
 */
export function recordDailyCompletion(
  dateStr: string,
  mistakes: number,
  storage: Storage | null = getDefaultStorage()
): RecordCompletionResult {
  const today = get_today_str();
  const data = getStreakData(storage);

  // If completed level is not today's level, streak is unaffected
  if (dateStr !== today) {
    return {
      currentStreak: data.currentStreak,
      bestStreak: data.bestStreak,
      streakIncreased: false,
      streakBroken: false,
      isEligibleToday: false,
    };
  }

  // If already completed today, return existing state
  if (data.lastCompletedDay === today) {
    return {
      currentStreak: data.currentStreak,
      bestStreak: data.bestStreak,
      streakIncreased: false,
      streakBroken: false,
      isEligibleToday: true,
    };
  }

  let streakIncreased = false;
  let streakBroken = false;

  if (mistakes <= STREAK_MAX_MISTAKES) {
    data.currentStreak += 1;
    data.bestStreak = Math.max(data.bestStreak, data.currentStreak);
    data.lastCompletedDay = today;
    streakIncreased = true;
  } else {
    data.currentStreak = 0;
    data.lastCompletedDay = today;
    streakBroken = true;
  }

  saveStreakData(data, storage);

  return {
    currentStreak: data.currentStreak,
    bestStreak: data.bestStreak,
    streakIncreased,
    streakBroken,
    isEligibleToday: true,
  };
}
