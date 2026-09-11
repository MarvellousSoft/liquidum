// src/engine/GridExporter.ts

import { E } from './E';
import { GridModel, LineHint, GridHints, CellHints, LoadMode } from './Grid';
import type { GridImpl, PureCell } from './GridImpl';
import { Content } from './GridImpl';

export const SAVE_VERSION = 2;

export enum ExportFields {
    version = 0,
    c_left = 1,
    c_right = 2,
    cell_type = 3,
    water_count = 4,
    water_count_type = 5,
    boat_count = 6,
    boat_count_type = 7,
    total_water = 8,
    total_boats = 9,
    expected_aquariums = 10,
    row_hints = 11,
    col_hints = 12,
    cells = 13,
    wall_bottom = 14,
    wall_right = 15,
    grid_hints = 16,
    cell_hints = 17,
    adj_water_count = 18,
    adj_water_count_type = 19
}

export class GridExporter {
    _export_pure_cell(pure: PureCell): Record<number, any> {
        return {
            [ExportFields.c_left]: pure.c_left,
            [ExportFields.c_right]: pure.c_right,
            [ExportFields.cell_type]: pure.cell_type(),
        };
    }

    _load_pure_cell(data: Record<number, any>, PureCellClass: any): PureCell {
        const cell: PureCell = PureCellClass.empty();
        cell.c_left = data[ExportFields.c_left];
        cell.c_right = data[ExportFields.c_right];
        cell.type = data[ExportFields.cell_type];
        return cell;
    }

    _export_grid<T, R>(grid: T[][], inner_export: (val: T) => R): R[][] {
        const exported: R[][] = [];
        for (let i = 0; i < grid.length; i++) {
            const row: R[] = [];
            for (let j = 0; j < grid[i].length; j++) {
                row.push(inner_export(grid[i][j]));
            }
            exported.push(row);
        }
        return exported;
    }

    _load_grid<R>(data: any[][], inner_load: (val: any) => R): R[][] {
        const grid: R[][] = [];
        if (!Array.isArray(data)) return grid;
        for (let i = 0; i < data.length; i++) {
            const row: R[] = [];
            for (let j = 0; j < data[i].length; j++) {
                row.push(inner_load(data[i][j]));
            }
            grid.push(row);
        }
        return grid;
    }

    _export_single_cell_hints(hints: CellHints | null): Record<number, any> {
        if (!hints) return {};
        return {
            [ExportFields.adj_water_count]: hints.adj_water_count,
            [ExportFields.adj_water_count_type]: hints.adj_water_count_type,
        };
    }

    _load_single_cell_hints(data: Record<number, any>): CellHints | null {
        if (!data || Object.keys(data).length === 0) return null;
        const c = new CellHints();
        c.adj_water_count = Number(data[ExportFields.adj_water_count]);
        c.adj_water_count_type = data[ExportFields.adj_water_count_type];
        return c;
    }

    _export_all_cell_hints(hints: (CellHints | null)[][]): any[] {
        const data: any[] = [];
        for (let i = 0; i < hints.length; i++) {
            for (let j = 0; j < hints[i].length; j++) {
                if (hints[i][j] != null) {
                    data.push([i, j, this._export_single_cell_hints(hints[i][j])]);
                }
            }
        }
        return data;
    }

    _load_all_cell_hints(data: any[], n: number, m: number): (CellHints | null)[][] {
        const hints: (CellHints | null)[][] = [];
        for (let i = 0; i < n; i++) {
            const row: (CellHints | null)[] = new Array(m).fill(null);
            hints.push(row);
        }
        if (Array.isArray(data)) {
            for (const s_data of data) {
                const i: number = s_data[0];
                const j: number = s_data[1];
                const hint_data = s_data[2];
                if (i >= 0 && i < n && j >= 0 && j < m) {
                    hints[i][j] = this._load_single_cell_hints(hint_data);
                }
            }
        }
        return hints;
    }

    _export_line_hint(line: LineHint): Record<number, any> {
        return {
            [ExportFields.water_count]: line.water_count,
            [ExportFields.water_count_type]: line.water_count_type,
            [ExportFields.boat_count]: line.boat_count,
            [ExportFields.boat_count_type]: line.boat_count_type,
        };
    }

    _load_line_hint(data: Record<number, any>): LineHint {
        const hint = new LineHint();
        hint.water_count = Number(data[ExportFields.water_count]);
        hint.water_count_type = data[ExportFields.water_count_type];
        hint.boat_count = Number(data[ExportFields.boat_count]);
        hint.boat_count_type = data[ExportFields.boat_count_type];
        return hint;
    }

    _export_bool(b: boolean): number {
        return b ? 1 : 0;
    }

    _load_bool(b: number | boolean): boolean {
        return b ? true : false;
    }

    _export_grid_hints(hints: GridHints): Record<number, any> {
        return {
            [ExportFields.total_water]: hints.total_water,
            [ExportFields.total_boats]: hints.total_boats,
            [ExportFields.expected_aquariums]: { ...hints.expected_aquariums },
        };
    }

    _load_grid_hints(data: Record<number, any>): GridHints {
        const hints = new GridHints();
        hints.total_water = Number(data[ExportFields.total_water]);
        hints.total_boats = Number(data[ExportFields.total_boats]);
        hints.expected_aquariums = {};
        const aqData = data[ExportFields.expected_aquariums] || {};
        for (const size in aqData) {
            hints.expected_aquariums[parseFloat(size)] = Number(aqData[size]);
        }
        return hints;
    }

    export_data(grid: GridImpl): Record<number, any> {
        return {
            [ExportFields.version]: SAVE_VERSION,
            [ExportFields.cells]: this._export_grid(grid.pure_cells, c => this._export_pure_cell(c)),
            [ExportFields.cell_hints]: this._export_all_cell_hints(grid.cell_hints),
            [ExportFields.row_hints]: grid._row_hints.map(h => this._export_line_hint(h)),
            [ExportFields.col_hints]: grid._col_hints.map(h => this._export_line_hint(h)),
            [ExportFields.wall_bottom]: this._export_grid(grid.wall_bottom, b => this._export_bool(b)),
            [ExportFields.wall_right]: this._export_grid(grid.wall_right, b => this._export_bool(b)),
            [ExportFields.grid_hints]: this._export_grid_hints(grid._grid_hints),
        };
    }

    _convert_keys_to_int(data: any): any {
        if (Array.isArray(data)) {
            return data.map(item => this._convert_keys_to_int(item));
        }
        if (data !== null && typeof data === 'object') {
            const res: Record<string | number, any> = {};
            for (const key in data) {
                const converted = this._convert_keys_to_int(data[key]);
                if (/^\d+$/.test(key)) {
                    res[parseInt(key, 10)] = converted;
                } else {
                    res[key] = converted;
                }
            }
            return res;
        }
        return data;
    }

    load_compatible_content(old_content: Content, new_content: Content): boolean {
        if (old_content === Content.Block) {
            return new_content === Content.Block;
        }
        return true;
    }

    load_compatible_cell(old_cell: PureCell, new_cell: PureCell): boolean {
        if (new_cell.cell_type() === E.CellType.Single && new_cell.c_left !== new_cell.c_right) {
            return false;
        }
        return old_cell.cell_type() === new_cell.cell_type() &&
            this.load_compatible_content(old_cell.c_left, new_cell.c_left) &&
            this.load_compatible_content(old_cell.c_right, new_cell.c_right);
    }

    load_compatible(old_grid: GridImpl, data: Record<number, any>, new_cells: PureCell[][]): boolean {
        const old_cells = old_grid.pure_cells;
        if (old_cells.length !== new_cells.length) return false;
        for (let i = 0; i < old_cells.length; i++) {
            if (old_cells[i].length !== new_cells[i].length) return false;
            for (let j = 0; j < old_cells[i].length; j++) {
                if (!this.load_compatible_cell(old_cells[i][j], new_cells[i][j])) {
                    return false;
                }
            }
        }
        const loadedWallBottom = this._load_grid(data[ExportFields.wall_bottom], b => this._load_bool(b));
        for (let i = 0; i < old_grid.wall_bottom.length; i++) {
            for (let j = 0; j < old_grid.wall_bottom[i].length; j++) {
                if (old_grid.wall_bottom[i][j] !== loadedWallBottom[i][j]) return false;
            }
        }
        const loadedWallRight = this._load_grid(data[ExportFields.wall_right], b => this._load_bool(b));
        for (let i = 0; i < old_grid.wall_right.length; i++) {
            for (let j = 0; j < old_grid.wall_right[i].length; j++) {
                if (old_grid.wall_right[i][j] !== loadedWallRight[i][j]) return false;
            }
        }
        return true;
    }

    load_data(grid: GridImpl, rawData: Record<any, any>, load_mode: LoadMode, PureCellClass: any): GridImpl {
        const data = this._convert_keys_to_int(rawData);
        if (data[ExportFields.version] < 2) {
            data[ExportFields.version] = 2;
            data[ExportFields.cell_hints] = [];
        }
        if (SAVE_VERSION !== data[ExportFields.version]) {
            console.warn("Invalid version in save data");
        }
        const content_only = (load_mode === LoadMode.ContentOnly);
        const new_cells = this._load_grid(data[ExportFields.cells], c => this._load_pure_cell(c, PureCellClass));
        if (content_only && !this.load_compatible(grid, data, new_cells)) {
            console.warn("Invalid save. Ignoring it and defaulting to empty grid.");
            return grid;
        }
        grid.pure_cells = new_cells;
        const n = grid.pure_cells.length;
        const m = n === 0 ? 0 : grid.pure_cells[0].length;
        if (content_only) {
            if (grid.n !== n || grid.m !== m) {
                throw new Error(`Grid dimensions mismatch: expected ${grid.n}x${grid.m}, got ${n}x${m}`);
            }
        } else {
            grid.n = n;
            grid.m = m;
            grid.cell_hints = this._load_all_cell_hints(data[ExportFields.cell_hints], n, m);
            grid._row_hints = data[ExportFields.row_hints].map((h: any) => this._load_line_hint(h));
            grid._col_hints = data[ExportFields.col_hints].map((h: any) => this._load_line_hint(h));
            grid.wall_bottom = this._load_grid(data[ExportFields.wall_bottom], b => this._load_bool(b));
            grid.wall_right = this._load_grid(data[ExportFields.wall_right], b => this._load_bool(b));
            grid._grid_hints = this._load_grid_hints(data[ExportFields.grid_hints]);
        }
        grid._finish_loading(load_mode);
        return grid;
    }
}
