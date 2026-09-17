// src/engine/DailyLevel.ts

import { RandomNumberGenerator } from '../model/RandomNumberGenerator';
import { GridImpl } from './GridImpl';
import { RandomLevelGenerator } from './RandomLevelGenerator';
import { consistent_hash } from './RandomHub';
import { Flavor, gen } from './RandomFlavors';
import { PreprocessedDailies } from './PreprocessedDailies';
import { getDailiesForYear } from './DailiesDatabase';
import type { GridModelData } from '../model/GridData';

export interface DailyLevelMeta {
    title: string;
    description: string;
    date: string;
    weekday: number;
    emoji: string;
    flavorName: string;
}

export const WEEKDAY_INFO: Record<number, { name: string; desc: string; emoji: string }> = {
    0: { name: "Aquarium Sunday", desc: "Diagonals and many aquarium hints visible.", emoji: "🐟" },
    1: { name: "Basic Monday", desc: "No special rules.", emoji: "💧" },
    2: { name: "Secret Boat Tuesday", desc: "Boats have hidden hints.", emoji: "⛵" },
    3: { name: "Diagonal Wednesday", desc: "Diagonals and no hidden hints.", emoji: "〽️" },
    4: { name: "Hidden Thursday", desc: "Hidden water hints, plus boats.", emoji: "❓" },
    5: { name: "Freaky Friday", desc: "Every rule, everywhere, all at once.", emoji: "💦" },
    6: { name: "One Row Saturday", desc: "Only one row hint is visible.", emoji: "1️⃣" },
};

export function get_today_str(d: Date = new Date()): string {
    const y = d.getUTCFullYear();
    const m = String(d.getUTCMonth() + 1).padStart(2, '0');
    const day = String(d.getUTCDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
}

export function get_yesterday_str(d: Date = new Date()): string {
    return shiftDate(get_today_str(d), -1);
}

export function getTimeLeftTodaySeconds(now: Date = new Date()): number {
    const nextMidnightUtc = Date.UTC(
        now.getUTCFullYear(),
        now.getUTCMonth(),
        now.getUTCDate() + 1,
        0, 0, 0
    );
    const diff = Math.floor((nextMidnightUtc - now.getTime()) / 1000);
    return Math.max(0, diff);
}

export function formatTimeLeft(secs: number): string {
    if (secs >= 24 * 3600) {
        const days = Math.floor(secs / (24 * 3600));
        const hours = Math.floor((secs % (24 * 3600)) / 3600);
        return `${days}d ${hours}h left`;
    }
    if (secs >= 3600) {
        const hours = Math.floor(secs / 3600);
        return `${hours}h left`;
    }
    const minutes = Math.floor(secs / 60);
    if (minutes <= 0) return "< 1 minute left";
    return `${minutes} minute${minutes !== 1 ? 's' : ''} left`;
}

export function formatTimeLeftDetailed(secs: number): string {
    const hours = Math.floor(secs / 3600);
    const minutes = Math.floor((secs % 3600) / 60);
    const seconds = secs % 60;
    if (hours > 0) {
        return `${hours}h ${String(minutes).padStart(2, '0')}m left`;
    }
    return `${minutes}m ${String(seconds).padStart(2, '0')}s left`;
}

export function formatSolveTimeGodot(secs: number): string {
    const hours = Math.floor(secs / 3600);
    const minutes = Math.floor((secs % 3600) / 60);
    const seconds = secs % 60;
    if (hours > 0) {
        return `${hours}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
    }
    return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
}

export function formatMistakesStr(mistakes: number): string {
    if (mistakes === 0) {
        return "🏆 0 mistakes";
    }
    return `❌ ${mistakes} ${mistakes > 1 ? "mistakes" : "mistake"}`;
}

export const SHARE_LINK = "linktr.ee/liquidum";

export function generateDailyShareText(opts: {
    dateStr: string;
    seconds: number;
    mistakes: number;
}): string {
    const { weekday } = parse_date(opts.dateStr);
    const info = WEEKDAY_INFO[weekday] || { name: "Daily Level", emoji: "🐟" };
    const timeStr = formatSolveTimeGodot(opts.seconds);
    const mistakesStr = formatMistakesStr(opts.mistakes);
    return `I won #liquidum daily on ${opts.dateStr}\n\n${info.emoji} ${info.name}\n🕑 ${timeStr}\n${mistakesStr}\n${SHARE_LINK}`;
}

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

export function shiftDate(date_str: string, days: number): string {
    const { year, month, day } = parse_date(date_str);
    const d = new Date(Date.UTC(year, month - 1, day + days));
    const y = d.getUTCFullYear();
    const m = String(d.getUTCMonth() + 1).padStart(2, '0');
    const dd = String(d.getUTCDate()).padStart(2, '0');
    return `${y}-${m}-${dd}`;
}

export function get_daily_meta(date_str: string): DailyLevelMeta {
    const { weekday } = parse_date(date_str);
    const info = WEEKDAY_INFO[weekday] || { name: "Daily Level", desc: "", emoji: "📅" };
    return {
        title: `${info.name} (${date_str})`,
        description: info.desc,
        date: date_str,
        weekday,
        emoji: info.emoji,
        flavorName: info.name
    };
}

export async function gen_daily_level(
    l_gen: RandomLevelGenerator,
    today_str: string,
    dailies_provider: (year: number) => Promise<PreprocessedDailies | null> = getDailiesForYear
): Promise<GridImpl | null> {
    const { year, month, day, weekday } = parse_date(today_str);
    const rng = new RandomNumberGenerator();
    rng.set_seed(consistent_hash(today_str));

    if (dailies_provider) {
        const dailies = await dailies_provider(year);
        if (dailies) {
            const preprocessed_state = dailies.success_state(month, day);
            if (preprocessed_state !== 0n) {
                rng.set_state(preprocessed_state);
            }
        }
    }

    return await gen(l_gen, rng, weekday as Flavor);
}

export async function load_daily_level_data(
    today_str?: string,
    dailies_provider: (year: number) => Promise<PreprocessedDailies | null> = getDailiesForYear
): Promise<{ engine: GridImpl; gridData: GridModelData; meta: DailyLevelMeta } | null> {
    const date_str = today_str || get_today_str();
    const l_gen = new RandomLevelGenerator();
    const engine = await gen_daily_level(l_gen, date_str, dailies_provider);
    if (!engine) return null;

    engine.clear_content();
    engine.undo_stack = [];
    engine.redo_stack = [];
    engine.maybe_update_hints();

    const gridData = engine.to_grid_data();
    const meta = get_daily_meta(date_str);

    return { engine, gridData, meta };
}
