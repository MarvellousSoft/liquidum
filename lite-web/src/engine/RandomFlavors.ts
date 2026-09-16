// src/engine/RandomFlavors.ts

import { RandomNumberGenerator } from '../model/RandomNumberGenerator';
import { Vector2i } from './Math';
import { GridImpl } from './GridImpl';
import { GeneratorOptions, Generator } from './Generator';
import {
    HintVisibility,
    WATER_COUNT_VISIBLE,
    WATER_TYPE_VISIBLE,
    BOAT_COUNT_VISIBLE,
    BOAT_TYPE_VISIBLE
} from './HintVisibility';
import {
    _vis_array_or,
    hide_too_easy_hints,
    _hard_visibility
} from './RandomHub';
import { SolverModel } from './Solver';
import type { RandomLevelGenerator } from './RandomLevelGenerator';

export enum Flavor {
    Aquariums = 0, // Sunday
    Basic = 1,     // Monday
    SecretBoats = 2, // Tuesday
    Diagonals = 3,   // Wednesday
    BoatsHiddenWater = 4, // Thursday
    Everything = 5,       // Friday
    OneHint = 6,          // Saturday
    TrickySmall = 7,
    AquariumTogether = 8,
    FemmeFatale = 9,
    CellHints1 = 10,
    CellHints2 = 11,
    CellHints3 = 12
}

export function _simple_hints(_rng: RandomNumberGenerator, grid: GridImpl): void {
    HintVisibility.default(grid.rows(), grid.cols()).apply_to_grid(grid);
}

export function _simple_boats(rng: RandomNumberGenerator, grid: GridImpl): void {
    const h = HintVisibility.default(grid.rows(), grid.cols());
    h.total_boats = rng.randf() < 0.5;
    for (const a of [h.row, h.col]) {
        _vis_array_or(rng, a, BOAT_COUNT_VISIBLE, rng.randi_range(0, Math.ceil(a.length * 0.75)));
    }
    h.apply_to_grid(grid);
}

export function _continuity_hints(rng: RandomNumberGenerator, grid: GridImpl): void {
    _hard_visibility(rng, grid);
}

export function _hidden_hints(rng: RandomNumberGenerator, grid: GridImpl): void {
    const h = HintVisibility.all_hidden(grid.rows(), grid.cols());
    h.total_water = rng.randf() < 0.5;
    for (const a of [h.row, h.col]) {
        _vis_array_or(rng, a, WATER_COUNT_VISIBLE, rng.randi_range(1, a.length - 1));
    }
    h.apply_to_grid(grid);
    hide_too_easy_hints(grid);
}

export function _boats_hidden_water(rng: RandomNumberGenerator, grid: GridImpl): void {
    const h = HintVisibility.default(grid.rows(), grid.cols(), WATER_TYPE_VISIBLE);
    h.total_boats = true;
    h.total_water = true;
    for (const a of [h.row, h.col]) {
        _vis_array_or(rng, a, BOAT_COUNT_VISIBLE, rng.randi_range(1, a.length + 3));
        if (a === h.row) {
            _vis_array_or(rng, a, BOAT_TYPE_VISIBLE, rng.randi_range(-2, a.length));
        }
    }
    h.apply_to_grid(grid);
    for (let i = 0; i < grid.rows(); i++) {
        if (grid.count_water_row(i) === 0) {
            grid.row_hints()[i].water_count = 0;
        }
    }
    for (let j = 0; j < grid.cols(); j++) {
        if (grid.count_water_col(j) === 0) {
            grid.col_hints()[j].water_count = 0;
        }
    }
}

export function _secret_boats(rng: RandomNumberGenerator, grid: GridImpl): void {
    const h = HintVisibility.all_hidden(grid.rows(), grid.cols());
    h.total_boats = true;
    h.total_water = rng.randf() < 0.5;
    for (let i = 0; i < grid.rows(); i++) {
        if (grid.count_boat_row(i) === 0) {
            h.row[i] |= BOAT_COUNT_VISIBLE;
        } else {
            h.row[i] |= BOAT_TYPE_VISIBLE;
        }
    }
    for (const a of [h.row, h.col]) {
        _vis_array_or(rng, a, WATER_COUNT_VISIBLE, rng.randi_range(1, a.length + 3));
    }
    h.apply_to_grid(grid);
    hide_too_easy_hints(grid);
}

export function _everything(rng: RandomNumberGenerator, grid: GridImpl): void {
    const h = HintVisibility.all_hidden(grid.rows(), grid.cols());
    h.total_boats = true;
    h.total_water = true;
    for (const a of [h.row, h.col]) {
        _vis_array_or(rng, a, WATER_COUNT_VISIBLE, rng.randi_range(1, a.length - 1));
        _vis_array_or(rng, a, WATER_TYPE_VISIBLE, rng.randi_range(1, a.length - 1));
        _vis_array_or(rng, a, BOAT_COUNT_VISIBLE, rng.randi_range(1, a.length - 1));
        if (a === h.row) {
            _vis_array_or(rng, a, BOAT_TYPE_VISIBLE, rng.randi_range(1, a.length - 1));
        }
    }
    const VIS = [
        WATER_COUNT_VISIBLE,
        WATER_TYPE_VISIBLE,
        WATER_COUNT_VISIBLE | WATER_TYPE_VISIBLE
    ];
    for (let i = 0; i < grid.rows(); i++) {
        for (let j = 0; j < grid.cols(); j++) {
            if (grid.get_cell(i, j).hints() != null) {
                h.cells.set(`${i},${j}`, VIS[rng.randi_range(0, 2)]);
            }
        }
    }
    h.apply_to_grid(grid);
    Generator.randomize_aquarium_hints(rng, grid);
    hide_too_easy_hints(grid);
}

export function _aquariums(rng: RandomNumberGenerator, grid: GridImpl): void {
    const h = HintVisibility.all_hidden(grid.rows(), grid.cols());
    h.total_water = true;
    for (const a of [h.row, h.col]) {
        _vis_array_or(rng, a, WATER_COUNT_VISIBLE, rng.randi_range(-3, a.length - 2));
    }
    h.apply_to_grid(grid);
    hide_too_easy_hints(grid);
    Generator.randomize_aquarium_hints(rng, grid, 0.66);
}

export function _one_hint(rng: RandomNumberGenerator, grid: GridImpl): void {
    const h = HintVisibility.all_hidden(grid.rows(), grid.cols());
    h.total_water = true;
    const a = h.col;
    const b = h.row;
    _vis_array_or(rng, a, WATER_COUNT_VISIBLE, rng.randi_range(a.length, a.length + 2));
    _vis_array_or(rng, a, WATER_TYPE_VISIBLE, rng.randi_range(a.length, a.length + 2));
    _vis_array_or(rng, b, WATER_COUNT_VISIBLE | WATER_TYPE_VISIBLE, 1);
    h.apply_to_grid(grid);
}

export function _tricky_small(rng: RandomNumberGenerator, grid: GridImpl): void {
    const h = HintVisibility.all_hidden(grid.rows(), grid.cols());
    h.total_water = rng.randf() < 0.25;
    for (const a of [h.row, h.col]) {
        _vis_array_or(rng, a, WATER_COUNT_VISIBLE, rng.randi_range(-3, a.length));
    }
    h.apply_to_grid(grid);
    hide_too_easy_hints(grid);
}

export function _aquarium_together(rng: RandomNumberGenerator, grid: GridImpl): void {
    const h = HintVisibility.all_hidden(grid.rows(), grid.cols());
    h.total_water = true;
    for (const a of [h.row, h.col]) {
        _vis_array_or(rng, a, WATER_TYPE_VISIBLE, rng.randi_range(-6, a.length));
    }
    h.apply_to_grid(grid);
    Generator.randomize_aquarium_hints(rng, grid, 0.7);
}

export function _cellhints_together(rng: RandomNumberGenerator, grid: GridImpl): void {
    const h = HintVisibility.all_hidden(grid.rows(), grid.cols());
    h.total_water = rng.randf() < 0.5;
    for (const a of [h.row, h.col]) {
        _vis_array_or(rng, a, WATER_COUNT_VISIBLE, rng.randi_range(0, a.length + 3));
        _vis_array_or(rng, a, WATER_TYPE_VISIBLE, rng.randi_range(-5, a.length - 1));
    }
    const cellhints: number[] = [];
    for (let i = 0; i < grid.rows(); i++) {
        for (let j = 0; j < grid.cols(); j++) {
            if (grid.get_cell(i, j).hints() != null) {
                cellhints.push(0);
            }
        }
    }
    _vis_array_or(rng, cellhints, WATER_COUNT_VISIBLE, rng.randi_range(1, cellhints.length + 2));
    _vis_array_or(rng, cellhints, WATER_TYPE_VISIBLE, rng.randi_range(1, cellhints.length));
    for (let i = 0; i < grid.rows(); i++) {
        for (let j = 0; j < grid.cols(); j++) {
            if (grid.get_cell(i, j).hints() != null) {
                const v = cellhints.pop()!;
                h.cells.set(`${i},${j}`, v !== 0 ? v : WATER_COUNT_VISIBLE);
            }
        }
    }
    h.apply_to_grid(grid);
    hide_too_easy_hints(grid);
}

export function _builder(options: GeneratorOptions): (rng: RandomNumberGenerator) => GeneratorOptions {
    return (_rng: RandomNumberGenerator) => options;
}

export function _aquarium_builder(rng: RandomNumberGenerator): GeneratorOptions {
    // In GDScript 4 method chaining: outer argument is evaluated before inner method callee!
    // .with_aquariums(...).with_min_water(...) evaluates with_min_water argument FIRST!
    const min_water = rng.randi_range(10, 14);
    const aquariums = rng.randi_range(6, 10);
    return Generator.builder()
        .with_diags()
        .with_aquariums(aquariums)
        .with_min_water(min_water);
}

export function _aquarium_together_builder(rng: RandomNumberGenerator): GeneratorOptions {
    const min_water = rng.randi_range(12, 18);
    const aquariums = rng.randi_range(10, 20);
    return Generator.builder()
        .with_aquariums(aquariums)
        .with_min_water(min_water);
}

export function _cellhints2_builder(rng: RandomNumberGenerator): GeneratorOptions {
    const opts = Generator.builder().with_cell_hints(rng.randf_range(0.01, 0.25));
    if (rng.randf() < 0.35) {
        opts.with_diags();
    }
    return opts;
}

export function _cellhints3_builder(rng: RandomNumberGenerator): GeneratorOptions {
    const opts = Generator.builder().with_cell_hints(rng.randf_range(0.01, 0.25));
    if (rng.randf() < 0.35) {
        opts.with_diags();
    }
    return opts;
}

export async function gen(
    l_gen: RandomLevelGenerator,
    rng: RandomNumberGenerator,
    flavor: Flavor
): Promise<GridImpl | null> {
    const strategies = Object.keys(SolverModel.STRATEGY_LIST);
    const b = () => Generator.builder();
    switch (flavor) {
        case Flavor.Diagonals:
            return await l_gen.generate(rng, 5, 5, _simple_hints, _builder(b().with_diags()), strategies, []);
        case Flavor.Basic:
            return await l_gen.generate(rng, 7, 7, _simple_hints, _builder(b()), strategies, []);
        case Flavor.BoatsHiddenWater:
            return await l_gen.generate(rng, 6, 6, _boats_hidden_water, _builder(b().with_boats()), strategies, [], true);
        case Flavor.SecretBoats:
            return await l_gen.generate(rng, 6, 6, _secret_boats, _builder(b().with_boats()), strategies, [], true);
        case Flavor.Everything:
            return await l_gen.generate(rng, 5, 5, _everything, _builder(b().with_diags().with_boats()), strategies, [], true);
        case Flavor.Aquariums:
            return await l_gen.generate(rng, 5, 4, _aquariums, _aquarium_builder, strategies, []);
        case Flavor.OneHint:
            return await l_gen.generate(rng, 6, 6, _one_hint, _builder(b()), strategies, []);
        case Flavor.TrickySmall: {
            const size_gen = (my_rng: RandomNumberGenerator) =>
                new Vector2i(my_rng.randi_range(3, 4), my_rng.randi_range(3, 4));
            return await l_gen.generate_with_size(rng, size_gen, _tricky_small, _builder(b().with_diags()), strategies, []);
        }
        case Flavor.AquariumTogether:
            return await l_gen.generate(rng, 6, 6, _aquarium_together, _aquarium_together_builder, strategies, [], false);
        case Flavor.CellHints1:
            return await l_gen.generate(rng, 7, 7, _simple_hints, _builder(b().with_cell_hints(0.1)), strategies, [], false);
        case Flavor.CellHints2:
            return await l_gen.generate(rng, 5, 6, _cellhints_together, _cellhints2_builder, strategies, [], false);
        case Flavor.CellHints3:
            return await l_gen.generate(rng, 5, 5, _everything, _builder(b().with_cell_hints(0.3).with_diags().with_boats()), strategies, [], false);
        default:
            console.error(`Unknown flavor ${flavor}`);
            return null;
    }
}
