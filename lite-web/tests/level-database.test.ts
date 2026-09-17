import { describe, test, expect } from 'vitest';
import {
  normalizeLevelKey,
  loadLevelData,
  TEST_LEVEL_KEYS,
} from '../src/engine/LevelDatabase';

describe('LevelDatabase', () => {
  test('TEST_LEVEL_KEYS contains standard test levels', () => {
    expect(TEST_LEVEL_KEYS).toContain('Level 01/01');
    expect(TEST_LEVEL_KEYS).toContain('Level 06/03');
    expect(TEST_LEVEL_KEYS.length).toBeGreaterThanOrEqual(10);
  });

  test('normalizeLevelKey correctly parses diverse level formats', () => {
    expect(normalizeLevelKey('Level 01/01')).toEqual({
      key: 'Level 01/01',
      section: '01',
      level: '01',
    });

    expect(normalizeLevelKey('01/05')).toEqual({
      key: 'Level 01/05',
      section: '01',
      level: '05',
    });

    expect(normalizeLevelKey('1/1')).toEqual({
      key: 'Level 01/01',
      section: '01',
      level: '01',
    });

    expect(normalizeLevelKey('Level 06-03')).toEqual({
      key: 'Level 06/03',
      section: '06',
      level: '03',
    });

    expect(normalizeLevelKey('04_01')).toEqual({
      key: 'Level 04/01',
      section: '04',
      level: '01',
    });

    expect(normalizeLevelKey('invalid')).toBeNull();
    expect(normalizeLevelKey('')).toBeNull();
  });

  test('loadLevelData dynamically loads level json and caches it', async () => {
    const data1 = await loadLevelData('Level 01/01');
    expect(data1).not.toBeNull();
    expect(data1.grid_data).toBeDefined();
    expect(data1.full_name).toBe('LEVEL_01_01');

    // Test loading via short string '01/01' returns same cached object
    const data2 = await loadLevelData('01/01');
    expect(data2).toBe(data1);

    // Test another section
    const dataBoat = await loadLevelData('04/01');
    expect(dataBoat).not.toBeNull();
    expect(dataBoat.full_name).toBe('LEVEL_04_01');
  });

  test('loadLevelData returns null for non-existent level', async () => {
    const nonExistent = await loadLevelData('99/99');
    expect(nonExistent).toBeNull();
  });
});
