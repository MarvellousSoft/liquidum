// src/engine/DailiesDatabase.ts

import { PreprocessedDailies } from './PreprocessedDailies';

let cached2024: PreprocessedDailies | null = null;
let cached2025: PreprocessedDailies | null = null;

export async function getDailiesForYear(year: number): Promise<PreprocessedDailies | null> {
    if (year === 2024) {
        if (!cached2024) {
            const module = await import('../database/dailies/2024.json');
            cached2024 = PreprocessedDailies.load_data(module.default as string[]);
        }
        return cached2024;
    }
    if (year === 2025) {
        if (!cached2025) {
            const module = await import('../database/dailies/2025.json');
            cached2025 = PreprocessedDailies.load_data(module.default as string[]);
        }
        return cached2025;
    }
    return null;
}
