// src/engine/StreakManager.ts
import { get_today_str, get_yesterday_str } from './DailyLevel';

export interface StreakData {
  currentStreak: number;
  bestStreak: number;
  lastCompletedDay: string | null;
}

export interface CloudStreakEntry {
  cur: number;
  best: number;
  last: string;
}

export type CloudStreakMap = Record<string, CloudStreakEntry>;

export interface StreakReconcileResult {
  mergedData: StreakData;
  localChanged: boolean;
  cloudChanged: boolean;
  updatedCloudMap: CloudStreakMap;
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


function defaultStreakData(): StreakData {
  return {
    currentStreak: 0,
    bestStreak: 0,
    lastCompletedDay: null
  };
}
function parseStreakEntry(entry: CloudStreakEntry | null): StreakData {
  if (!entry) return defaultStreakData();
  return {
    currentStreak: entry.cur || 0,
    bestStreak: entry.best || 0,
    lastCompletedDay: entry.last || null,
  }
}

/**
 * Safely parses raw JSON PlayFab UserData streaks into CloudStreakMap.
 */
export function parseCloudStreakMap(rawJson: string | null | undefined): CloudStreakMap {
  if (!rawJson || typeof rawJson !== 'string') return {};
  try {
    const parsed = JSON.parse(rawJson);
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
      return parsed as CloudStreakMap;
    }
  } catch {
    // Malformed JSON
  }
  return {};
}

/**
 * Serializes CloudStreakMap to compact JSON string for PlayFab UserData.
 */
export function serializeCloudStreakMap(map: CloudStreakMap): string {
  return JSON.stringify(map);
}

/**
 * Reconciles local streak data with cloud streaks.
 * Preserves non-daily keys (like 'weekly') in updatedCloudMap.
 */
export function reconcileStreak(
  localData: StreakData,
  cloudMap: CloudStreakMap | null,
  todayStr?: string,
  yesterdayStr?: string
): StreakReconcileResult {
  const today = todayStr || get_today_str();
  const yesterday = yesterdayStr || get_yesterday_str();
  const updatedCloudMap: CloudStreakMap = cloudMap ? { ...cloudMap } : {};
  const cloudDailyRaw: CloudStreakEntry | null = updatedCloudMap['daily'] || null;
  const cloudDaily: StreakData = parseStreakEntry(cloudDailyRaw);

  const effectiveStreak = (data: StreakData) => {
    if (data.lastCompletedDay == today || data.lastCompletedDay == yesterday)
      return data.currentStreak;
    return 0;
  };


  // Pre-validation / expiry normalization
  const effectiveLocalCur = effectiveStreak(localData);
  const effectiveCloudCur = effectiveStreak(cloudDaily);

  // Best streak is strictly monotonic
  const mergedBest = Math.max(
    localData.bestStreak,
    cloudDaily.bestStreak,
  );

  let mergedCur = 0;
  let mergedLast: string | null = null;

  const hasCloud = Boolean(cloudDaily.lastCompletedDay && cloudDaily.lastCompletedDay.trim() !== '');
  const hasLocal = Boolean(localData.lastCompletedDay && localData.lastCompletedDay.trim() !== '');

  if (!hasCloud && !hasLocal) {
    // Neither has history
    mergedCur = 0;
    mergedLast = null;
  } else if (!hasCloud) {
    // Local only
    mergedCur = effectiveLocalCur;
    mergedLast = localData.lastCompletedDay;
  } else if (!hasLocal) {
    // Cloud only
    mergedCur = effectiveCloudCur;
    mergedLast = cloudDaily.lastCompletedDay;
  } else {
    const cmp = localData.lastCompletedDay!.localeCompare(cloudDaily.lastCompletedDay!);
    if (cmp > 0) {
      // Local played more recently (e.g. offline play)
      mergedCur = effectiveLocalCur;
      mergedLast = localData.lastCompletedDay;
    } else if (cmp < 0) {
      // Cloud played more recently (e.g. on another device)
      mergedCur = effectiveCloudCur;
      mergedLast = cloudDaily.lastCompletedDay;
    } else {
      // Same period completed on both devices
      mergedLast = localData.lastCompletedDay;
      mergedCur = Math.max(effectiveLocalCur, effectiveCloudCur);
    }
  }

  const mergedData: StreakData = {
    currentStreak: mergedCur,
    bestStreak: mergedBest,
    lastCompletedDay: mergedLast,
  };

  const localChanged =
    mergedData.currentStreak !== localData.currentStreak ||
    mergedData.bestStreak !== localData.bestStreak ||
    mergedData.lastCompletedDay !== localData.lastCompletedDay;

  const newCloudDaily: CloudStreakEntry = {
    cur: mergedData.currentStreak,
    best: mergedData.bestStreak,
    last: mergedData.lastCompletedDay || '',
  };

  const hasCloudData = Boolean(cloudDailyRaw);
  const hasAnyData = hasCloud || hasLocal || mergedBest > 0;

  let cloudChanged = false;
  if (!hasCloudData) {
    cloudChanged = hasAnyData;
  } else {
    cloudChanged =
      cloudDailyRaw!.cur !== newCloudDaily.cur ||
      cloudDailyRaw!.best !== newCloudDaily.best ||
      cloudDailyRaw!.last !== newCloudDaily.last;
  }

  if (hasAnyData || hasCloudData) {
    updatedCloudMap['daily'] = newCloudDaily;
  }

  return {
    mergedData,
    localChanged,
    cloudChanged,
    updatedCloudMap,
  };
}

/**
 * Synchronizes local streak data in storage with provided cloud streak map.
 */
export function syncLocalWithCloudStreaks(
  cloudMap: CloudStreakMap | null,
  storage: Storage | null = getDefaultStorage(),
  todayStr?: string,
  yesterdayStr?: string
): { mergedData: StreakData; cloudNeedsUpdate: boolean; updatedCloudMap: CloudStreakMap } {
  const local = getStreakData(storage);
  const result = reconcileStreak(local, cloudMap, todayStr, yesterdayStr);
  if (result.localChanged) {
    saveStreakData(result.mergedData, storage);
  }
  return {
    mergedData: result.mergedData,
    cloudNeedsUpdate: result.cloudChanged,
    updatedCloudMap: result.updatedCloudMap,
  };
}

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
  const defaultData: StreakData = defaultStreakData();

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
