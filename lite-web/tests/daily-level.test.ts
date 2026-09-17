import { describe, test, expect } from 'vitest';
import {
  parse_date,
  get_today_str,
  get_daily_meta,
  load_daily_level_data,
  WEEKDAY_INFO
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
});
