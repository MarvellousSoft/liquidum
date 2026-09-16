// src/engine/Generator.ts

import { E } from './E';
import { Vector2i, Rect2i } from './Math';
import { RandomNumberGenerator } from '../model/RandomNumberGenerator';
import { GridImpl } from './GridImpl';

export class GeneratorOptions {
    diagonals: boolean = false;
    boats: boolean = false;
    // Just a hint, doesn't need to be strictly satisfied
    aquarium_count: number = 0;
    min_water: number = 0;
    cell_hints: number = 0.0;

    with_boats(b: boolean = true): this {
        this.boats = b;
        return this;
    }

    with_diags(b: boolean = true): this {
        this.diagonals = b;
        return this;
    }

    with_aquariums(count: number): this {
        this.aquarium_count = count;
        return this;
    }

    with_min_water(count: number): this {
        this.min_water = count;
        return this;
    }

    with_cell_hints(pct: number = 0.0): this {
        this.cell_hints = pct;
        return this;
    }

    build(rseed: number | bigint): Generator {
        return new Generator(rseed, this);
    }
}

export function shuffle<T>(a: T[], rng: RandomNumberGenerator): void {
    for (let i = 0; i < a.length; i++) {
        const j = rng.randi_range(i, a.length - 1);
        const tmp = a[i];
        a[i] = a[j];
        a[j] = tmp;
    }
}

export function pop_random(arr: Vector2i[], rng: RandomNumberGenerator): Vector2i {
    if (arr.length === 0) {
        return new Vector2i(-1, -1);
    }
    const i = rng.randi_range(0, arr.length - 1);
    const val = arr[i];
    arr[i] = arr[arr.length - 1];
    arr.pop();
    return val;
}

export abstract class AdjacencyRule {
    abstract all_adj(from: Vector2i, boats: boolean): Vector2i[];
}

const DV: Vector2i[] = [
    new Vector2i(1, 0),
    new Vector2i(-1, 0),
    new Vector2i(0, 1),
    new Vector2i(0, -1)
];

export class SquareAdj extends AdjacencyRule {
    all_adj(from: Vector2i, boats: boolean): Vector2i[] {
        const adj: Vector2i[] = DV.map(d => new Vector2i(from.x + d.x, from.y + d.y));
        // Hack: make things more vertical when there's boats
        if (boats) {
            adj.push(new Vector2i(from.x + DV[0].x, from.y + DV[0].y));
            adj.push(new Vector2i(from.x + DV[1].x, from.y + DV[1].y));
        }
        return adj;
    }
}

export class DiagAdj extends AdjacencyRule {
    dec_diag: boolean[][] = [];

    constructor(rng: RandomNumberGenerator, n: number, m: number) {
        super();
        for (let i = 0; i < n; i++) {
            const row: boolean[] = [];
            for (let j = 0; j < m; j++) {
                row.push(rng.randf() < 0.5);
            }
            this.dec_diag.push(row);
        }
    }

    third_adj(from: Vector2i): Vector2i {
        const oj = Math.floor(from.y / 2);
        // Connects to top
        if (this.dec_diag[from.x][oj] !== ((from.y & 1) === 0)) {
            const extra = (from.x === 0 || !this.dec_diag[from.x - 1][oj]) ? 1 : 0;
            return new Vector2i(from.x - 1, oj * 2 + extra);
        } else { // Connects to bottom
            const extra = (from.x === this.dec_diag.length - 1 || this.dec_diag[from.x + 1][oj]) ? 1 : 0;
            return new Vector2i(from.x + 1, oj * 2 + extra);
        }
    }

    all_adj(from: Vector2i, boats: boolean): Vector2i[] {
        const adj: Vector2i[] = [
            new Vector2i(from.x, from.y - 1),
            new Vector2i(from.x, from.y + 1),
            this.third_adj(from)
        ];
        // Hack: make things more vertical when there's boats
        if (boats) {
            adj.push(adj[adj.length - 1]);
        }
        return adj;
    }
}

export class Generator {
    rng: RandomNumberGenerator = new RandomNumberGenerator();
    opts: GeneratorOptions;

    static builder(): GeneratorOptions {
        return new GeneratorOptions();
    }

    constructor(rseed: number | bigint, opts: GeneratorOptions) {
        this.rng.set_seed(rseed);
        this.opts = opts;
    }

    wrand(mx: number, weight: number): number {
        let val = this.rng.randi_range(1, mx);
        for (let i = 0; i < weight; i++) {
            val = Math.min(val, this.rng.randi_range(1, mx));
        }
        return val;
    }

    any_empty(g: number[][]): Vector2i {
        const i_order: number[] = Array.from({ length: g.length }, (_, i) => i);
        shuffle(i_order, this.rng);
        for (const i of i_order) {
            const j_order: number[] = Array.from({ length: g[i].length }, (_, j) => j);
            shuffle(j_order, this.rng);
            for (const j of j_order) {
                if (g[i][j] === 0) {
                    return new Vector2i(i, j);
                }
            }
        }
        return new Vector2i(-1, -1);
    }

    _gen_grid_groups(n: number, m: number, adj_rule: AdjacencyRule): number[][] {
        let aqs: number;
        if (this.opts.diagonals) {
            m *= 2;
        }
        if (this.opts.aquarium_count > 0) {
            aqs = this.opts.aquarium_count - 1;
        } else {
            const min_aqs = this.opts.diagonals ? Math.floor((n * m) / 5) : Math.floor((n * m) / 2.5);
            aqs = this.rng.randi_range(min_aqs, Math.floor((n * m) / 2));
        }
        const g: number[][] = [];
        for (let i = 0; i < n; i++) {
            g.push(new Array(m).fill(0));
        }
        let left = n * m;
        let group = 0;
        // Break groups into similar sizes, this uses the "sticks and rocks" technique
        const group_sizes: number[] = [left - 1];
        for (let group_i = 0; group_i < aqs; group_i++) {
            let s = this.rng.randi_range(0, left - 2 - group_i);
            for (let j = 0; j < group_i + 1; j++) {
                if (s < group_sizes[j]) {
                    const rest = group_sizes[j] - s;
                    group_sizes[j] = s;
                    group_sizes.push(rest - 1);
                    break;
                }
                s -= group_sizes[j];
            }
        }
        const all_empty: Vector2i[] = [];
        for (let i = 0; i < n; i++) {
            for (let j = 0; j < m; j++) {
                all_empty.push(new Vector2i(i, j));
            }
        }
        shuffle(all_empty, this.rng);
        while (left > 0) {
            group += 1;
            let group_size = group_sizes.pop()! + 1;
            if (group_sizes.length === 0) {
                group_sizes.push(5);
            }
            left -= 1;
            while (g[all_empty[all_empty.length - 1].x][all_empty[all_empty.length - 1].y] !== 0) {
                all_empty.pop();
            }
            const cells: Vector2i[] = [all_empty.pop()!];
            g[cells[0].x][cells[0].y] = group;
            const all_adj: Vector2i[] = adj_rule.all_adj(cells[0], this.opts.boats);
            for (let _i = 0; _i < group_size; _i++) {
                let c = pop_random(all_adj, this.rng);
                while (!(c.x === -1 && c.y === -1) && (c.x < 0 || c.x >= n || c.y < 0 || c.y >= m || g[c.x][c.y] !== 0)) {
                    c = pop_random(all_adj, this.rng);
                }
                if (c.x === -1 && c.y === -1) {
                    break;
                }
                g[c.x][c.y] = group;
                cells.push(c);
                all_adj.push(...adj_rule.all_adj(c, this.opts.boats));
                left -= 1;
            }
        }
        return g;
    }

    _all_cells(grid: GridImpl): Vector2i[] {
        const all_cells: Vector2i[] = [];
        for (let i = 0; i < grid.rows(); i++) {
            for (let j = 0; j < grid.cols(); j++) {
                all_cells.push(new Vector2i(i, j));
            }
        }
        return all_cells;
    }

    randomize_boats(grid: GridImpl): void {
        const all_cells = this._all_cells(grid);
        shuffle(all_cells, this.rng);
        const boat_pct = this.rng.randf_range(0.3, 0.9);
        for (const idx of all_cells) {
            const c = grid.get_cell(idx.x, idx.y);
            if (!c.boat_possible()) {
                continue;
            }
            if (this.rng.randf() < boat_pct) {
                if (!c.put_boat(true)) {
                    console.error("Boat placing should succeed");
                }
            }
        }
    }

    randomize_cell_hints(grid: GridImpl): void {
        const all_cells = this._all_cells(grid);
        shuffle(all_cells, this.rng);
        let count = this.rng.randi_range(1, Math.round(grid.rows() * grid.cols() * this.opts.cell_hints));
        for (const idx of all_cells) {
            const water_around = grid.count_water_adj(idx.x, idx.y);
            const size_around = new Rect2i(0, 0, grid.rows(), grid.cols())
                .intersection(new Rect2i(idx.x - 1, idx.y - 1, 3, 3))
                .get_area();
            if (water_around !== 0 && water_around !== size_around) {
                grid.get_cell(idx.x, idx.y).add_cell_hints();
                count -= 1;
                if (count <= 0) {
                    break;
                }
            }
        }
    }

    randomize_water(grid: GridImpl, flush_undo: boolean = true): void {
        if (flush_undo) {
            grid.push_empty_undo();
        }
        let min_water = this.opts.min_water;
        if (min_water === 0) {
            min_water = Math.floor((grid.rows() * grid.cols() - grid.count_blocks()) * this.rng.randf_range(0.2, 0.75));
        }
        let water_wanted = min_water - grid.count_waters();
        if (water_wanted < 0) {
            return;
        }
        const all_cells = this._all_cells(grid);
        while (all_cells.length > 0) {
            const idx = pop_random(all_cells, this.rng);
            const c = grid.get_cell(idx.x, idx.y);
            for (const corner of c.corners()) {
                if (c.nothing_at(corner)) {
                    water_wanted -= c.put_water(corner, false);
                    if (water_wanted <= 0) {
                        return;
                    }
                }
            }
        }
    }

    static randomize_aquarium_hints(rng: RandomNumberGenerator, grid: GridImpl, aq_pct: number = 0.5): void {
        const all_aqs = grid.all_aquarium_counts_ordered();
        // Add some small sizes that may be 0 if not already present
        if (!all_aqs.has(0.0)) {
            all_aqs.set(0.0, 0);
        }
        let any_diags = false;
        for (let i = 0; i < grid.rows(); i++) {
            for (let j = 0; j < grid.cols(); j++) {
                if (grid.get_cell(i, j).cell_type() !== E.CellType.Single) {
                    any_diags = true;
                    break;
                }
            }
            if (any_diags) break;
        }
        if (any_diags) {
            if (!all_aqs.has(0.5)) {
                all_aqs.set(0.5, 0);
            }
        }
        if (!all_aqs.has(1.0)) {
            all_aqs.set(1.0, 0);
        }
        const expected = grid.grid_hints().expected_aquariums;
        for (const [sz, count] of all_aqs) {
            if (rng.randf() < aq_pct) {
                expected[sz] = count;
            }
        }
    }

    generate(n: number, m: number): GridImpl {
        // Reset rng
        this.rng.set_seed(this.rng.get_seed());
        let adj_rule: AdjacencyRule;
        if (this.opts.diagonals) {
            adj_rule = new DiagAdj(this.rng, n, m);
        } else {
            adj_rule = new SquareAdj();
        }

        const g = this._gen_grid_groups(n, m, adj_rule);
        const grid = GridImpl.empty_editor(n, m);
        // Update hints once at the end
        grid.set_auto_update_hints(false);
        for (let i = 0; i < n; i++) {
            for (let j = 0; j < m; j++) {
                if (this.opts.diagonals) {
                    const diag_adj = adj_rule as DiagAdj;
                    if (j < m - 1 && g[i][2 * j + 1] !== g[i][2 * j + 2]) {
                        grid.get_cell(i, j).put_wall(E.Walls.Right, false, true);
                    }
                    const from = diag_adj.dec_diag[i][j] ? new Vector2i(i, 2 * j) : new Vector2i(i, 2 * j + 1);
                    const bottom = diag_adj.third_adj(from);
                    if (i < n - 1 && g[from.x][from.y] !== g[bottom.x][bottom.y]) {
                        grid.get_cell(i, j).put_wall(E.Walls.Bottom, false, true);
                    }
                    if (g[i][2 * j] !== g[i][2 * j + 1]) {
                        grid.get_cell(i, j).put_wall(diag_adj.dec_diag[i][j] ? E.Walls.DecDiag : E.Walls.IncDiag, false, true);
                    }
                } else {
                    if (j < m - 1 && g[i][j] !== g[i][j + 1]) {
                        grid.get_cell(i, j).put_wall(E.Walls.Right, false, true);
                    }
                    if (i < n - 1 && g[i][j] !== g[i + 1][j]) {
                        grid.get_cell(i, j).put_wall(E.Walls.Bottom, false, true);
                    }
                }
            }
        }
        if (this.opts.boats) {
            this.randomize_boats(grid);
        }
        this.randomize_water(grid, false);
        if (this.opts.cell_hints > 0) {
            this.randomize_cell_hints(grid);
        }
        grid.set_auto_update_hints(true);
        return grid;
    }
}
