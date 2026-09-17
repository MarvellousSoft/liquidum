// src/engine/LevelDatabase.ts
// Dynamic loading of test / campaign level JSONs on demand

export const TEST_LEVEL_KEYS: string[] = [
  "Level 01/01",
  "Level 01/05",
  "Level 02/01",
  "Level 03/01",
  "Level 03/07",
  "Level 04/01",
  "Level 04/05",
  "Level 05/01",
  "Level 05/08",
  "Level 06/01",
  "Level 06/03",
];

const levelCache = new Map<string, any>();

/**
 * Normalizes various level input strings (e.g. "01/01", "Level 01/01", "1/1", "01-01")
 * into formatted section ("01"), level ("01"), and canonical key ("Level 01/01").
 */
export function normalizeLevelKey(input: string): { key: string; section: string; level: string } | null {
  if (!input) return null;
  const cleaned = input.trim();

  // Match "Level 01/01", "01/01", "1/1", "01-01", "1_1"
  const match = cleaned.match(/(?:level\s*)?(\d{1,2})[\/\-_](\d{1,2})/i);
  if (!match) return null;

  const sectionNum = parseInt(match[1], 10);
  const levelNum = parseInt(match[2], 10);

  if (isNaN(sectionNum) || isNaN(levelNum)) return null;

  const section = String(sectionNum).padStart(2, '0');
  const level = String(levelNum).padStart(2, '0');
  const key = `Level ${section}/${level}`;

  return { key, section, level };
}

/**
 * Dynamically loads level JSON data from database.
 */
export async function loadLevelData(levelKeyOrShort: string): Promise<any | null> {
  const norm = normalizeLevelKey(levelKeyOrShort);
  if (!norm) return null;

  if (levelCache.has(norm.key)) {
    return levelCache.get(norm.key);
  }

  try {
    const module = await import(`../database/levels/${norm.section}/${norm.level}.json`);
    const data = module.default;
    levelCache.set(norm.key, data);
    return data;
  } catch (err) {
    console.warn(`Failed to dynamically import level ${norm.key}:`, err);
    return null;
  }
}
