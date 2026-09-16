// src/engine/DailyLevel.ts

import { RandomNumberGenerator } from '../model/RandomNumberGenerator';
import { GridImpl } from './GridImpl';
import { RandomLevelGenerator } from './RandomLevelGenerator';
import { consistent_hash } from './RandomHub';
import { Flavor, gen } from './RandomFlavors';
import { PreprocessedDailies } from './PreprocessedDailies';

export function parse_date(date_str: string): { year: number; month: number; day: number; weekday: number } {
    const parts = date_str.split('-');
    const year = parseInt(parts[0], 10);
    const month = parseInt(parts[1], 10);
    const day = parseInt(parts[2], 10);
    // In Godot and JS Date.getUTCDay(): 0 = Sunday, 1 = Monday, ..., 6 = Saturday
    const date = new Date(Date.UTC(year, month - 1, day));
    const weekday = date.getUTCDay();
    return { year, month, day, weekday };
}

export async function gen_daily_level(
    l_gen: RandomLevelGenerator,
    today_str: string,
    dailies_provider?: (year: number) => PreprocessedDailies | null
): Promise<GridImpl | null> {
    const { year, month, day, weekday } = parse_date(today_str);
    const rng = new RandomNumberGenerator();
    rng.set_seed(consistent_hash(today_str));

    if (dailies_provider) {
        const dailies = dailies_provider(year);
        if (dailies) {
            const preprocessed_state = dailies.success_state(month, day);
            if (preprocessed_state !== 0n) {
                rng.set_state(preprocessed_state);
            }
        }
    }

    return await gen(l_gen, rng, weekday as Flavor);
}
