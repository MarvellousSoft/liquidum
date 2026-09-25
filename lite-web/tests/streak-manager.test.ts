import { describe, test, expect, beforeEach } from 'vitest';
import {
  getStreakData,
  recordDailyCompletion,
  STREAK_STORAGE_KEY,
  saveStreakData,
  parseCloudStreakMap,
  serializeCloudStreakMap,
  reconcileStreak,
  syncLocalWithCloudStreaks,
} from '../src/engine/StreakManager';
import { get_today_str, get_yesterday_str, shiftDate } from '../src/engine/DailyLevel';

class MockStorage implements Storage {
  private store: Record<string, string> = {};

  get length(): number {
    return Object.keys(this.store).length;
  }

  clear(): void {
    this.store = {};
  }

  getItem(key: string): string | null {
    return this.store[key] !== undefined ? this.store[key] : null;
  }

  key(index: number): string | null {
    return Object.keys(this.store)[index] || null;
  }

  removeItem(key: string): void {
    delete this.store[key];
  }

  setItem(key: string, value: string): void {
    this.store[key] = value;
  }
}

describe('StreakManager', () => {
  let mockStorage: MockStorage;

  beforeEach(() => {
    mockStorage = new MockStorage();
  });

  test('returns 0 streak initially when storage is empty', () => {
    const data = getStreakData(mockStorage);
    expect(data.currentStreak).toBe(0);
    expect(data.bestStreak).toBe(0);
    expect(data.lastCompletedDay).toBeNull();
  });

  test('increments streak when solving today with <= 2 mistakes', () => {
    const today = get_today_str();

    // Day 1 completion with 0 mistakes
    const res1 = recordDailyCompletion(today, 0, mockStorage);
    expect(res1.currentStreak).toBe(1);
    expect(res1.bestStreak).toBe(1);
    expect(res1.streakIncreased).toBe(true);
    expect(res1.streakBroken).toBe(false);

    const saved = getStreakData(mockStorage);
    expect(saved.currentStreak).toBe(1);
    expect(saved.bestStreak).toBe(1);
    expect(saved.lastCompletedDay).toBe(today);
  });

  test('does not double count when already solved today', () => {
    const today = get_today_str();

    recordDailyCompletion(today, 1, mockStorage);
    const res2 = recordDailyCompletion(today, 0, mockStorage);

    expect(res2.currentStreak).toBe(1);
    expect(res2.streakIncreased).toBe(false);
  });

  test('breaks streak when solving today with > 2 mistakes', () => {
    const today = get_today_str();
    const yesterday = get_yesterday_str();

    // Had an existing streak of 5 from yesterday
    saveStreakData(
      {
        currentStreak: 5,
        bestStreak: 10,
        lastCompletedDay: yesterday,
      },
      mockStorage
    );

    // Solved today with 3 mistakes -> streak resets to 0, best streak preserved
    const res = recordDailyCompletion(today, 3, mockStorage);
    expect(res.currentStreak).toBe(0);
    expect(res.bestStreak).toBe(10);
    expect(res.streakBroken).toBe(true);

    const saved = getStreakData(mockStorage);
    expect(saved.currentStreak).toBe(0);
    expect(saved.bestStreak).toBe(10);
    expect(saved.lastCompletedDay).toBe(today);
  });

  test('does not alter streak when completing an older past level', () => {
    const today = get_today_str();
    const olderDate = shiftDate(today, -5);

    saveStreakData(
      {
        currentStreak: 3,
        bestStreak: 3,
        lastCompletedDay: get_yesterday_str(),
      },
      mockStorage
    );

    const res = recordDailyCompletion(olderDate, 0, mockStorage);
    expect(res.currentStreak).toBe(3);
    expect(res.streakIncreased).toBe(false);
    expect(res.isEligibleToday).toBe(false);

    const saved = getStreakData(mockStorage);
    expect(saved.currentStreak).toBe(3);
  });

  test('resets streak to 0 if user missed a day', () => {
    const today = get_today_str();
    const twoDaysAgo = shiftDate(today, -2);

    // Last completed was 2 days ago (missed yesterday)
    saveStreakData(
      {
        currentStreak: 4,
        bestStreak: 4,
        lastCompletedDay: twoDaysAgo,
      },
      mockStorage
    );

    const data = getStreakData(mockStorage);
    expect(data.currentStreak).toBe(0);
    expect(data.bestStreak).toBe(4);
  });

  describe('Cloud Streak Reconciliation & Serialization', () => {
    test('parseCloudStreakMap and serializeCloudStreakMap round-trip', () => {
      const raw = '{"daily":{"cur":5,"best":10,"last":"2026-09-24"},"weekly":{"cur":2,"best":4,"last":"2026-09-21"}}';
      const parsed = parseCloudStreakMap(raw);
      expect(parsed.daily).toEqual({ cur: 5, best: 10, last: '2026-09-24' });
      expect(parsed.weekly).toEqual({ cur: 2, best: 4, last: '2026-09-21' });

      const serialized = serializeCloudStreakMap(parsed);
      expect(JSON.parse(serialized)).toEqual(JSON.parse(raw));
    });

    test('parseCloudStreakMap handles null/empty/invalid input gracefully', () => {
      expect(parseCloudStreakMap(null)).toEqual({});
      expect(parseCloudStreakMap(undefined)).toEqual({});
      expect(parseCloudStreakMap('')).toEqual({});
      expect(parseCloudStreakMap('not a json')).toEqual({});
      expect(parseCloudStreakMap('[]')).toEqual({});
    });

    test('fresh device adopts cloud streak', () => {
      const today = '2026-09-24';
      const yesterday = '2026-09-23';
      const local = { currentStreak: 0, bestStreak: 0, lastCompletedDay: null };
      const cloud = {
        daily: { cur: 7, best: 12, last: today },
      };

      const result = reconcileStreak(local, cloud, today, yesterday);
      expect(result.mergedData.currentStreak).toBe(7);
      expect(result.mergedData.bestStreak).toBe(12);
      expect(result.mergedData.lastCompletedDay).toBe(today);
      expect(result.localChanged).toBe(true);
      expect(result.cloudChanged).toBe(false);
    });

    test('local offline progress takes precedence over older cloud progress', () => {
      const today = '2026-09-24';
      const yesterday = '2026-09-23';
      // Local played today offline
      const local = { currentStreak: 6, bestStreak: 10, lastCompletedDay: today };
      // Cloud only had yesterday's streak
      const cloud = {
        daily: { cur: 5, best: 10, last: yesterday },
      };

      const result = reconcileStreak(local, cloud, today, yesterday);
      expect(result.mergedData.currentStreak).toBe(6);
      expect(result.mergedData.bestStreak).toBe(10);
      expect(result.mergedData.lastCompletedDay).toBe(today);
      expect(result.localChanged).toBe(false);
      expect(result.cloudChanged).toBe(true);
      expect(result.updatedCloudMap.daily).toEqual({ cur: 6, best: 10, last: today });
    });

    test('cloud progress takes precedence over older local progress', () => {
      const today = '2026-09-24';
      const yesterday = '2026-09-23';
      // Local was last played yesterday
      const local = { currentStreak: 5, bestStreak: 10, lastCompletedDay: yesterday };
      // Cloud played today on another device
      const cloud = {
        daily: { cur: 6, best: 10, last: today },
      };

      const result = reconcileStreak(local, cloud, today, yesterday);
      expect(result.mergedData.currentStreak).toBe(6);
      expect(result.mergedData.bestStreak).toBe(10);
      expect(result.mergedData.lastCompletedDay).toBe(today);
      expect(result.localChanged).toBe(true);
      expect(result.cloudChanged).toBe(false);
    });

    test('tie-break on same day picks higher streak and maximum best streak', () => {
      const today = '2026-09-24';
      const yesterday = '2026-09-23';
      // Device A failed on replay or broke streak
      const local = { currentStreak: 0, bestStreak: 8, lastCompletedDay: today };
      // Device B completed with win
      const cloud = {
        daily: { cur: 4, best: 15, last: today },
      };

      const result = reconcileStreak(local, cloud, today, yesterday);
      expect(result.mergedData.currentStreak).toBe(4);
      expect(result.mergedData.bestStreak).toBe(15);
      expect(result.mergedData.lastCompletedDay).toBe(today);
      expect(result.localChanged).toBe(true);
      expect(result.cloudChanged).toBe(false);
    });

    test('preserves weekly marathon data when updating daily streak', () => {
      const today = '2026-09-24';
      const yesterday = '2026-09-23';
      const local = { currentStreak: 3, bestStreak: 5, lastCompletedDay: today };
      const cloud = {
        daily: { cur: 2, best: 5, last: yesterday },
        weekly: { cur: 4, best: 8, last: '2026-09-21' },
      };

      const result = reconcileStreak(local, cloud, today, yesterday);
      expect(result.updatedCloudMap.daily).toEqual({ cur: 3, best: 5, last: today });
      // Weekly must remain untouched!
      expect(result.updatedCloudMap.weekly).toEqual({ cur: 4, best: 8, last: '2026-09-21' });
    });

    test('resets streak to 0 if days were missed before sync', () => {
      const today = '2026-09-24';
      const yesterday = '2026-09-23';
      const fourDaysAgo = '2026-09-20';

      const local = { currentStreak: 10, bestStreak: 10, lastCompletedDay: fourDaysAgo };
      const cloud = {
        daily: { cur: 10, best: 10, last: fourDaysAgo },
      };

      const result = reconcileStreak(local, cloud, today, yesterday);
      expect(result.mergedData.currentStreak).toBe(0);
      expect(result.mergedData.bestStreak).toBe(10);
      expect(result.mergedData.lastCompletedDay).toBe(fourDaysAgo);
    });

    test('syncLocalWithCloudStreaks persists to storage when local changed', () => {
      const today = get_today_str();
      const cloud = {
        daily: { cur: 8, best: 14, last: today },
      };

      const res = syncLocalWithCloudStreaks(cloud, mockStorage);
      expect(res.mergedData.currentStreak).toBe(8);
      expect(res.mergedData.bestStreak).toBe(14);

      const saved = getStreakData(mockStorage);
      expect(saved.currentStreak).toBe(8);
      expect(saved.bestStreak).toBe(14);
      expect(saved.lastCompletedDay).toBe(today);
    });
  });
});
