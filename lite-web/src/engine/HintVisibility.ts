// src/engine/HintVisibility.ts

import { E } from './E';
import { GridHints, LineHint, CellHints } from './Grid';
import { GridImpl } from './GridImpl';

export const WATER_COUNT_VISIBLE = 1;
export const WATER_TYPE_VISIBLE = 2;
export const BOAT_COUNT_VISIBLE = 4;
export const BOAT_TYPE_VISIBLE = 8;

export class HintVisibility {
    total_water: boolean = false;
    total_boats: boolean = true;
    expected_aquariums: number[] = [];
    row: number[] = [];
    col: number[] = [];
    cells: Map<string, number> = new Map();
    default_cell_flag: number = WATER_COUNT_VISIBLE;

    static default(n: number, m: number, start: number = WATER_COUNT_VISIBLE): HintVisibility {
        const h = new HintVisibility();
        h.default_cell_flag = start;
        for (let i = 0; i < n; i++) {
            h.row.push(start);
        }
        for (let j = 0; j < m; j++) {
            h.col.push(start);
        }
        return h;
    }

    static all_hidden(n: number, m: number): HintVisibility {
        return HintVisibility.default(n, m, 0);
    }

    static from_grid(grid: GridImpl): HintVisibility {
        const h = new HintVisibility();
        h.total_water = grid.grid_hints().total_water !== -1;
        h.total_boats = grid.grid_hints().total_boats !== -1;
        h.expected_aquariums = Object.keys(grid.grid_hints().expected_aquariums).map(x => parseFloat(x));
        h.row = grid.row_hints().map(HintVisibility._hint_to_flag);
        h.col = grid.col_hints().map(HintVisibility._hint_to_flag);
        for (let i = 0; i < grid.rows(); i++) {
            for (let j = 0; j < grid.cols(); j++) {
                const c = grid.get_cell(i, j).hints();
                if (c != null) {
                    h.cells.set(`${i},${j}`, HintVisibility._cell_hint_to_flag(c));
                }
            }
        }
        return h;
    }

    static _cell_hint_to_flag(hint: CellHints): number {
        let val = 0;
        if (hint.adj_water_count !== -1) {
            val |= WATER_COUNT_VISIBLE;
        }
        if (hint.adj_water_count_type !== E.HintType.Hidden) {
            val |= WATER_TYPE_VISIBLE;
        }
        return val;
    }

    static _hint_to_flag(hint: LineHint): number {
        let val = 0;
        if (hint.water_count !== -1) {
            val |= WATER_COUNT_VISIBLE;
        }
        if (hint.water_count_type !== E.HintType.Hidden) {
            val |= WATER_TYPE_VISIBLE;
        }
        if (hint.boat_count !== -1) {
            val |= BOAT_COUNT_VISIBLE;
        }
        if (hint.boat_count_type !== E.HintType.Hidden) {
            val |= BOAT_TYPE_VISIBLE;
        }
        return val;
    }

    _update_line_hint(line_hint: LineHint, flags: number): void {
        if (!(flags & BOAT_COUNT_VISIBLE)) {
            line_hint.boat_count = -1;
        }
        if (!(flags & BOAT_TYPE_VISIBLE) || line_hint.boat_count_type === E.HintType.Zero) {
            line_hint.boat_count_type = E.HintType.Hidden;
        }
        if (!(flags & WATER_COUNT_VISIBLE)) {
            line_hint.water_count = -1.0;
        }
        if (!(flags & WATER_TYPE_VISIBLE) || line_hint.water_count_type === E.HintType.Zero) {
            line_hint.water_count_type = E.HintType.Hidden;
        }
    }

    _update_cell_hint(hint: CellHints, flags: number): void {
        if (!(flags & WATER_COUNT_VISIBLE)) {
            hint.adj_water_count = -1.0;
        }
        if (!(flags & WATER_TYPE_VISIBLE) || hint.adj_water_count_type === E.HintType.Zero) {
            hint.adj_water_count_type = E.HintType.Hidden;
        }
    }

    apply_to_grid(grid: GridImpl): void {
        const ghints = grid.grid_hints();
        const prev_boats = ghints.total_boats;
        if (!this.total_water) {
            ghints.total_water = -1;
        }
        if (!this.total_boats) {
            ghints.total_boats = -1;
        }
        const all_aqs = grid.all_aquarium_counts();
        ghints.expected_aquariums = {};
        for (const aq of this.expected_aquariums) {
            ghints.expected_aquariums[aq] = all_aqs[aq] || 0;
        }
        for (let i = 0; i < grid.rows(); i++) {
            this._update_line_hint(grid.row_hints()[i], this.row[i]);
        }
        for (let j = 0; j < grid.cols(); j++) {
            this._update_line_hint(grid.col_hints()[j], this.col[j]);
        }
        for (let i = 0; i < grid.rows(); i++) {
            for (let j = 0; j < grid.cols(); j++) {
                const h = grid.get_cell(i, j).hints();
                if (h != null) {
                    const flags = this.cells.has(`${i},${j}`) ? this.cells.get(`${i},${j}`)! : this.default_cell_flag;
                    this._update_cell_hint(h, flags);
                }
            }
        }
        // Force boat amount if it would create schrodinger boats
        if (grid.any_schrodinger_boats()) {
            ghints.total_boats = prev_boats;
        }
        grid.validate();
    }
}
