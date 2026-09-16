import { describe, test, expect } from 'vitest';
import * as crypto from 'crypto';
import * as fs from 'fs';
import * as path from 'path';
import { RandomNumberGenerator } from '../src/model/RandomNumberGenerator';
import { Vector2i } from '../src/engine/Math';
import { Generator } from '../src/engine/Generator';
import { consistent_hash, sha1, gen_from_difficulty, Difficulty } from '../src/engine/RandomHub';
import { RandomLevelGenerator } from '../src/engine/RandomLevelGenerator';
import { PreprocessedDailies } from '../src/engine/PreprocessedDailies';
import { gen_daily_level, parse_date } from '../src/engine/DailyLevel';
import { Flavor, gen } from '../src/engine/RandomFlavors';

describe('Generator and Daily Level Parity', () => {
    test('consistent_hash matches Node crypto SHA-1 little-endian int64', () => {
        const testStrings = [
            '2024-01-01',
            '2024-05-15',
            '2025-12-31',
            'random',
            '0',
            '1',
            '42',
            'daily_button',
            'hello world'
        ];

        for (const s of testStrings) {
            const hash = crypto.createHash('sha1').update(s, 'utf8').digest();
            const expectedBigInt = hash.readBigInt64LE(0);
            const actualBigInt = consistent_hash(s);
            expect(actualBigInt).toBe(expectedBigInt);
        }
    });

    test('Generator is deterministic for same seed and options', () => {
        const seed = 12345;
        const opts = Generator.builder().with_diags().with_boats().with_cell_hints(0.2);

        const gen1 = opts.build(seed);
        const grid1 = gen1.generate(5, 5);

        const gen2 = opts.build(seed);
        const grid2 = gen2.generate(5, 5);

        expect(grid1.to_str()).toBe(grid2.to_str());
        expect(grid1.export_data()).toEqual(grid2.export_data());
    });

    test('Generator generates valid solvable hints', () => {
        const seed = 99999;
        const opts = Generator.builder().with_boats();
        const grid = opts.build(seed).generate(6, 6);

        expect(grid.rows()).toBe(6);
        expect(grid.cols()).toBe(6);
        expect(grid.are_hints_satisfied()).toBe(true);
    });

    test('PreprocessedDailies loads 2024 database correctly', () => {
        const dailiesPath = path.resolve(__dirname, '../../project/database/dailies/2024.json');
        expect(fs.existsSync(dailiesPath)).toBe(true);

        const jsonContent = JSON.parse(fs.readFileSync(dailiesPath, 'utf8'));
        const dailies = PreprocessedDailies.load_data(jsonContent);

        // 2024-01-01 is index 0
        const jan1State = dailies.success_state(1, 1);
        expect(jan1State).toBe(BigInt('-7291427775475410410'));

        // 2024-01-02 is index 1
        const jan2State = dailies.success_state(1, 2);
        expect(jan2State).toBe(BigInt('-3942542506262854830'));
    });

    test('Daily level generation matches preprocessed state for 2024-01-01 (Monday Basic)', async () => {
        const dailiesPath = path.resolve(__dirname, '../../project/database/dailies/2024.json');
        const jsonContent = JSON.parse(fs.readFileSync(dailiesPath, 'utf8'));
        const dailies = PreprocessedDailies.load_data(jsonContent);

        const l_gen = new RandomLevelGenerator();
        const grid = await gen_daily_level(l_gen, '2024-01-01', (_year) => dailies);

        expect(grid).not.toBeNull();
        expect(l_gen.success_state).toBe(BigInt('-7291427775475410410'));
        expect(grid!.are_hints_satisfied()).toBe(true);
    }, 15000);

    test('Daily level generation matches preprocessed state for 2024-01-02 (Tuesday Secret Boats)', async () => {
        const dailiesPath = path.resolve(__dirname, '../../project/database/dailies/2024.json');
        const jsonContent = JSON.parse(fs.readFileSync(dailiesPath, 'utf8'));
        const dailies = PreprocessedDailies.load_data(jsonContent);

        const l_gen = new RandomLevelGenerator();
        const grid = await gen_daily_level(l_gen, '2024-01-02', (_year) => dailies);

        expect(grid).not.toBeNull();
        expect(l_gen.success_state).toBe(BigInt('-3942542506262854830'));
        expect(grid!.count_boats()).toBeGreaterThan(0);
        expect(grid!.are_hints_satisfied(true)).toBe(true);
    }, 15000);

    test('Daily level generation matches preprocessed state for 2024-01-03 (Wednesday Diagonals)', async () => {
        const dailiesPath = path.resolve(__dirname, '../../project/database/dailies/2024.json');
        const jsonContent = JSON.parse(fs.readFileSync(dailiesPath, 'utf8'));
        const dailies = PreprocessedDailies.load_data(jsonContent);

        const l_gen = new RandomLevelGenerator();
        const grid = await gen_daily_level(l_gen, '2024-01-03', (_year) => dailies);

        expect(grid).not.toBeNull();
        expect(l_gen.success_state).toBe(BigInt('-2446488056476808301'));
        expect(grid!.are_hints_satisfied(true)).toBe(true);
    }, 15000);

    test('Daily level generation matches preprocessed state for 2024-01-04 (Thursday Hidden)', async () => {
        const dailiesPath = path.resolve(__dirname, '../../project/database/dailies/2024.json');
        const jsonContent = JSON.parse(fs.readFileSync(dailiesPath, 'utf8'));
        const dailies = PreprocessedDailies.load_data(jsonContent);

        const l_gen = new RandomLevelGenerator();
        const grid = await gen_daily_level(l_gen, '2024-01-04', (_year) => dailies);

        expect(grid).not.toBeNull();
        expect(l_gen.success_state).toBe(BigInt('-1274953987845688554'));
        expect(grid!.are_hints_satisfied(true)).toBe(true);
    }, 15000);

    test('Daily level generation matches preprocessed state for 2024-01-05 (Friday Everything)', async () => {
        const dailiesPath = path.resolve(__dirname, '../../project/database/dailies/2024.json');
        const jsonContent = JSON.parse(fs.readFileSync(dailiesPath, 'utf8'));
        const dailies = PreprocessedDailies.load_data(jsonContent);

        const l_gen = new RandomLevelGenerator();
        const grid = await gen_daily_level(l_gen, '2024-01-05', (_year) => dailies);

        expect(grid).not.toBeNull();
        expect(l_gen.success_state).toBe(BigInt('5751444286601836662'));
        expect(grid!.are_hints_satisfied(true)).toBe(true);
    }, 15000);

    test('Daily level generation matches preprocessed state for 2024-01-06 (Saturday OneHint)', async () => {
        const dailiesPath = path.resolve(__dirname, '../../project/database/dailies/2024.json');
        const jsonContent = JSON.parse(fs.readFileSync(dailiesPath, 'utf8'));
        const dailies = PreprocessedDailies.load_data(jsonContent);

        const l_gen = new RandomLevelGenerator();
        const grid = await gen_daily_level(l_gen, '2024-01-06', (_year) => dailies);

        expect(grid).not.toBeNull();
        expect(l_gen.success_state).toBe(BigInt('3170767684919336858'));
        expect(grid!.are_hints_satisfied(true)).toBe(true);
    }, 15000);

    test('Daily level generation matches preprocessed state for 2024-01-07 (Sunday Aquariums)', async () => {
        const dailiesPath = path.resolve(__dirname, '../../project/database/dailies/2024.json');
        const jsonContent = JSON.parse(fs.readFileSync(dailiesPath, 'utf8'));
        const dailies = PreprocessedDailies.load_data(jsonContent);

        const l_gen = new RandomLevelGenerator();
        const grid = await gen_daily_level(l_gen, '2024-01-07', (_year) => dailies);

        expect(grid).not.toBeNull();
        expect(l_gen.success_state).toBe(BigInt('671727193315551376'));
        expect(grid!.are_hints_satisfied(true)).toBe(true);
    }, 15000);
});
