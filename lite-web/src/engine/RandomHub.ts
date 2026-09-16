// src/engine/RandomHub.ts

import { RandomNumberGenerator } from '../model/RandomNumberGenerator';
import { GridImpl } from './GridImpl';
import { GeneratorOptions, Generator, shuffle } from './Generator';
import {
    HintVisibility,
    WATER_COUNT_VISIBLE,
    WATER_TYPE_VISIBLE,
    BOAT_COUNT_VISIBLE,
    BOAT_TYPE_VISIBLE
} from './HintVisibility';
import { SolverModel } from './Solver';
import type { RandomLevelGenerator } from './RandomLevelGenerator';

export enum Difficulty {
    Easy = 0,
    Medium = 1,
    Hard = 2,
    Expert = 3,
    Insane = 4
}

// Synchronous RFC 3174 SHA-1 for cross-platform deterministic hashing
export function sha1(str: string): Uint8Array {
    const encoder = new TextEncoder();
    const bytes = encoder.encode(str);
    const len = bytes.length;
    const bitLen = len * 8;
    const padLen = ((len + 8) >>> 6 << 6) + 64;
    const padded = new Uint8Array(padLen);
    padded.set(bytes);
    padded[len] = 0x80;
    const view = new DataView(padded.buffer);
    view.setBigUint64(padLen - 8, BigInt(bitLen), false);

    let h0 = 0x67452301, h1 = 0xefcdab89, h2 = 0x98badcfe, h3 = 0x10325476, h4 = 0xc3d2e1f0;
    const w = new Int32Array(80);

    for (let offset = 0; offset < padLen; offset += 64) {
        for (let i = 0; i < 16; i++) {
            w[i] = view.getInt32(offset + i * 4, false);
        }
        for (let i = 16; i < 80; i++) {
            const v = w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16];
            w[i] = (v << 1) | (v >>> 31);
        }
        let a = h0, b = h1, c = h2, d = h3, e = h4;
        for (let i = 0; i < 80; i++) {
            let f: number, k: number;
            if (i < 20) {
                f = (b & c) | ((~b) & d);
                k = 0x5a827999;
            } else if (i < 40) {
                f = b ^ c ^ d;
                k = 0x6ed9eba1;
            } else if (i < 60) {
                f = (b & c) | (b & d) | (c & d);
                k = 0x8f1bbcdc;
            } else {
                f = b ^ c ^ d;
                k = 0xca62c1d6;
            }
            const temp = (((a << 5) | (a >>> 27)) + f + e + k + w[i]) | 0;
            e = d;
            d = c;
            c = (b << 30) | (b >>> 2);
            b = a;
            a = temp;
        }
        h0 = (h0 + a) | 0;
        h1 = (h1 + b) | 0;
        h2 = (h2 + c) | 0;
        h3 = (h3 + d) | 0;
        h4 = (h4 + e) | 0;
    }
    const out = new Uint8Array(20);
    const outView = new DataView(out.buffer);
    outView.setInt32(0, h0, false);
    outView.setInt32(4, h1, false);
    outView.setInt32(8, h2, false);
    outView.setInt32(12, h3, false);
    outView.setInt32(16, h4, false);
    return out;
}

// Godot: x.sha1_buffer().decode_s64(0)
export function consistent_hash(x: string): bigint {
    const digest = sha1(x);
    const view = new DataView(digest.buffer, digest.byteOffset, digest.byteLength);
    return view.getBigInt64(0, true);
}

export function _vis_array_or(rng: RandomNumberGenerator, a: number[], val: number, count: number): void {
    const b: number[] = [];
    for (let i = 0; i < a.length; i++) {
        b.push(i < count ? val : 0);
    }
    shuffle(b, rng);
    for (let i = 0; i < a.length; i++) {
        a[i] |= b[i];
    }
}

// If a hint is 0 or the size of row/col, hide it. This makes puzzles more interesting.
export function hide_too_easy_hints(grid: GridImpl, rows: boolean = true, cols: boolean = true): void {
    if (rows) {
        const hints = grid.row_hints();
        for (let i = 0; i < grid.rows(); i++) {
            if (hints[i].water_count === grid.cols() || hints[i].water_count === 0) {
                hints[i].water_count = -1;
            }
        }
    }
    if (cols) {
        const hints = grid.col_hints();
        for (let j = 0; j < grid.cols(); j++) {
            if (hints[j].water_count === grid.rows() || hints[j].water_count === 0) {
                hints[j].water_count = -1;
            }
        }
    }
}

export function _easy_visibility(_rng: RandomNumberGenerator, grid: GridImpl): void {
    HintVisibility.default(grid.rows(), grid.cols()).apply_to_grid(grid);
}

export function _medium_visibility(rng: RandomNumberGenerator, grid: GridImpl): void {
    const h = HintVisibility.all_hidden(grid.rows(), grid.cols());
    for (const a of [h.row, h.col]) {
        _vis_array_or(rng, a, WATER_COUNT_VISIBLE, Math.min(rng.randi_range(3, a.length + 2), a.length));
        _vis_array_or(rng, a, WATER_TYPE_VISIBLE, Math.max(rng.randi_range(-3, a.length - 2), 0));
    }
    h.apply_to_grid(grid);
    hide_too_easy_hints(grid);
}

export function _hard_visibility(rng: RandomNumberGenerator, grid: GridImpl): void {
    const h = HintVisibility.all_hidden(grid.rows(), grid.cols());
    h.total_boats = rng.randf() < 0.5;
    h.total_water = rng.randf() < 0.3;
    for (const a of [h.row, h.col]) {
        _vis_array_or(rng, a, WATER_COUNT_VISIBLE, Math.min(rng.randi_range(1, a.length + 3), a.length));
        _vis_array_or(rng, a, WATER_TYPE_VISIBLE, Math.max(rng.randi_range(-3, a.length), 0));
        _vis_array_or(rng, a, BOAT_COUNT_VISIBLE, rng.randi_range(0, Math.ceil(a.length / 2)));
    }
    h.apply_to_grid(grid);
    hide_too_easy_hints(grid);
}

export function _expert_visibility(rng: RandomNumberGenerator, grid: GridImpl): void {
    const h = HintVisibility.all_hidden(grid.rows(), grid.cols());
    h.total_boats = rng.randf() < 0.5;
    h.total_water = rng.randf() < 0.3;
    for (const a of [h.row, h.col]) {
        _vis_array_or(rng, a, WATER_COUNT_VISIBLE, Math.min(rng.randi_range(0, a.length), a.length));
        _vis_array_or(rng, a, WATER_TYPE_VISIBLE, Math.max(rng.randi_range(-4, a.length), 0));
        _vis_array_or(rng, a, BOAT_COUNT_VISIBLE, rng.randi_range(0, Math.ceil(a.length / 2)));
    }
    h.apply_to_grid(grid);
    hide_too_easy_hints(grid);
    if (rng.randf() < 0.35) {
        Generator.randomize_aquarium_hints(rng, grid);
    }
}

export function _expert_options(rng: RandomNumberGenerator): GeneratorOptions {
    return Generator.builder().with_diags(rng.randf() < 0.5).with_boats(rng.randf() < 0.35);
}

export function _diags(rng: RandomNumberGenerator): GeneratorOptions {
    return Generator.builder().with_diags().with_boats(rng.randf() < 0.5);
}

export function _nothing(_rng: RandomNumberGenerator): GeneratorOptions {
    return Generator.builder();
}

export async function gen_from_difficulty(
    l_gen: RandomLevelGenerator,
    rng: RandomNumberGenerator,
    dif: Difficulty
): Promise<GridImpl | null> {
    switch (dif) {
        case Difficulty.Easy:
            return await l_gen.generate(
                rng, 5, 5,
                _easy_visibility,
                _nothing,
                ["BasicRow", "BasicCol", "CellBasic"],
                []
            );
        case Difficulty.Medium:
            return await l_gen.generate(
                rng, 6, 6,
                _medium_visibility,
                _nothing,
                ["BasicCol", "BasicRow", "CellBasic", "TogetherRowBasic", "TogetherColBasic", "SeparateRowBasic", "SeparateColBasic"],
                ["MediumCol", "MediumRow", "FullPropagateNoWater"]
            );
        case Difficulty.Hard:
            return await l_gen.generate(
                rng, 5, 4,
                _hard_visibility,
                _diags,
                ["BasicCol", "BasicRow", "CellBasic", "FullPropagateNoWater", "MediumCol", "MediumRow", "AllWatersEasy", "BoatRow"],
                ["TogetherRowBasic", "TogetherColBasic", "SeparateRowBasic", "SeparateColBasic", "BoatCol", "AllBoats", "AllWatersMedium"]
            );
        case Difficulty.Expert:
            return await l_gen.generate(
                rng, 5, 5,
                _expert_visibility,
                _expert_options,
                ["BasicCol", "BasicRow", "CellBasic", "FullPropagateNoWater", "MediumCol", "MediumRow", "BoatRow", "BoatCol", "AllWatersEasy", "AllWatersMedium", "AllBoats", "TogetherRowBasic", "TogetherColBasic", "SeparateRowBasic", "SeparateColBasic", "AquariumsBasic"],
                ["TogetherRowAdvanced", "TogetherColAdvanced", "SeparateRowAdvanced", "SeparateColAdvanced", "AdvancedRow", "AdvancedCol", "AquariumsAdvanced"]
            );
        case Difficulty.Insane:
            return await l_gen.generate(
                rng, 6, 6,
                _expert_visibility,
                _expert_options,
                Object.keys(SolverModel.STRATEGY_LIST),
                []
            );
        default:
            console.error(`Unknown difficulty ${dif}`);
            return null;
    }
}
