// src/engine/DailiesDatabase.ts

import { PreprocessedDailies } from './PreprocessedDailies';
import dailies2024 from '../database/dailies/2024.json';
import dailies2025 from '../database/dailies/2025.json';

let cached2024: PreprocessedDailies | null = null;
let cached2025: PreprocessedDailies | null = null;

export function getDailiesForYear(year: number): PreprocessedDailies | null {
    if (year === 2024) {
        if (!cached2024) {
            cached2024 = PreprocessedDailies.load_data(dailies2024 as string[]);
        }
        return cached2024;
    }
    if (year === 2025) {
        if (!cached2025) {
            cached2025 = PreprocessedDailies.load_data(dailies2025 as string[]);
        }
        return cached2025;
    }
    return null;
}
