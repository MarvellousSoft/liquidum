import { describe, test, expect, beforeEach } from 'vitest';
import {
  getStreakData,
  recordDailyCompletion,
  STREAK_STORAGE_KEY,
  saveStreakData,
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
});
