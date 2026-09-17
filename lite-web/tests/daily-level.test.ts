import { describe, test, expect } from 'vitest';
import {
  parse_date,
  get_today_str,
  get_daily_meta,
  load_daily_level_data,
  WEEKDAY_INFO,
  getTimeLeftTodaySeconds,
  formatTimeLeft,
  generateDailyShareText,
} from '../src/engine/DailyLevel';
import { getDailiesForYear } from '../src/engine/DailiesDatabase';
import { Content } from '../src/model/GridData';

describe('Daily Level Loading and Integration', () => {
  test('parse_date parses ISO date strings correctly', () => {
    const d1 = parse_date('2024-01-01');
    expect(d1.year).toBe(2024);
    expect(d1.month).toBe(1);
    expect(d1.day).toBe(1);
    expect(d1.weekday).toBe(1); // Monday

    const d7 = parse_date('2024-01-07');
    expect(d7.weekday).toBe(0); // Sunday
  });

  test('get_today_str returns valid YYYY-MM-DD format', () => {
    const todayStr = get_today_str();
    expect(todayStr).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  test('get_daily_meta returns correct weekday metadata', () => {
    const metaSun = get_daily_meta('2024-01-07');
    expect(metaSun.flavorName).toBe('Aquarium Sunday');
    expect(metaSun.emoji).toBe('🐟');

    const metaMon = get_daily_meta('2024-01-01');
    expect(metaMon.flavorName).toBe('Basic Monday');
    expect(metaMon.emoji).toBe('💧');

    const metaTue = get_daily_meta('2024-01-02');
    expect(metaTue.flavorName).toBe('Secret Boat Tuesday');
    expect(metaTue.emoji).toBe('⛵');
  });

  test('getDailiesForYear loads 2024 and 2025 databases', async () => {
    const d2024 = await getDailiesForYear(2024);
    expect(d2024).not.toBeNull();
    expect(d2024?.success_state(1, 1)).toBe(BigInt('-7291427775475410410'));

    const d2025 = await getDailiesForYear(2025);
    expect(d2025).not.toBeNull();

    const d2026 = await getDailiesForYear(2026);
    expect(d2026).toBeNull();
  });

  test('load_daily_level_data generates ready-to-play level with cleared player cells and valid solution', async () => {
    const result = await load_daily_level_data('2024-01-01');
    expect(result).not.toBeNull();
    if (!result) return;

    const { engine, gridData, meta } = result;
    expect(meta.title).toContain('Basic Monday');
    expect(meta.date).toBe('2024-01-01');

    // Player grid cells must be empty (cleared) so user can play
    for (let r = 0; r < gridData.cells.length; r++) {
      for (let c = 0; c < gridData.cells[r].length; c++) {
        const cell = gridData.cells[r][c];
        if (cell.c_left !== Content.Block) {
          expect(cell.c_left).toBe(Content.Nothing);
        }
        if (cell.c_right !== Content.Block) {
          expect(cell.c_right).toBe(Content.Nothing);
        }
      }
    }

    // Solution must be stored
    expect(gridData.solution_c_left).toBeDefined();
    expect(gridData.solution_c_right).toBeDefined();
    expect(gridData.solution_c_left!.length).toBe(gridData.cells.length);

    // Initial player state is not complete
    expect(engine.are_hints_satisfied()).toBe(false);
  });

  test('get_today_str rolls over at 00:00 UTC (9:00 PM Sao Paulo UTC-3)', () => {
    // 2026-09-16 at 20:59:00 BRT (UTC-3) -> 23:59:00 UTC on 2026-09-16
    const beforeReset = new Date('2026-09-16T23:59:00Z');
    expect(get_today_str(beforeReset)).toBe('2026-09-16');

    // 2026-09-16 at 21:00:00 BRT (UTC-3) -> 00:00:00 UTC on 2026-09-17
    const atReset = new Date('2026-09-17T00:00:00Z');
    expect(get_today_str(atReset)).toBe('2026-09-17');

    // 2026-09-16 at 21:30:00 BRT (UTC-3) -> 00:30:00 UTC on 2026-09-17
    const afterReset = new Date('2026-09-17T00:30:00Z');
    expect(get_today_str(afterReset)).toBe('2026-09-17');
  });

  test('getTimeLeftTodaySeconds and formatTimeLeft calculate correct remaining duration', () => {
    // 3 hours and 15 minutes before UTC midnight
    const threeHoursLeft = new Date('2026-09-16T20:45:00Z');
    const secs = getTimeLeftTodaySeconds(threeHoursLeft);
    expect(secs).toBe(3 * 3600 + 15 * 60);

    const formattedHours = formatTimeLeft(secs);
    expect(formattedHours).toBe('3h left');

    // 45 minutes before UTC midnight
    const fortyFiveMins = 45 * 60;
    expect(formatTimeLeft(fortyFiveMins)).toBe('45 minutes left');

    // 1 minute before UTC midnight
    expect(formatTimeLeft(60)).toBe('1 minute left');

    // Under 1 minute
    expect(formatTimeLeft(20)).toBe('< 1 minute left');
  });

  test('generateDailyShareText formats exact Godot parity result text', () => {
    // Perfect solve (0 mistakes)
    const share0 = generateDailyShareText({
      dateStr: '2024-01-07', // Sunday
      seconds: 85,
      mistakes: 0,
    });
    expect(share0).toBe(
      'I won #liquidum daily on 2024-01-07\n\n🐟 Aquarium Sunday\n🕑 01:25\n🏆 0 mistakes\nlinktr.ee/liquidum'
    );

    // 1 mistake
    const share1 = generateDailyShareText({
      dateStr: '2024-01-01', // Monday
      seconds: 65,
      mistakes: 1,
    });
    expect(share1).toBe(
      'I won #liquidum daily on 2024-01-01\n\n💧 Basic Monday\n🕑 01:05\n❌ 1 mistake\nlinktr.ee/liquidum'
    );

    // 3 mistakes and > 1 hour
    const share3 = generateDailyShareText({
      dateStr: '2024-01-02', // Tuesday
      seconds: 3665, // 1h 1m 5s
      mistakes: 3,
    });
    expect(share3).toBe(
      'I won #liquidum daily on 2024-01-02\n\n⛵ Secret Boat Tuesday\n🕑 1:01:05\n❌ 3 mistakes\nlinktr.ee/liquidum'
    );
  });
});
