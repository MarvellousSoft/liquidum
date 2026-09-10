import { E } from './E';
import { GridModel, CellModel, LineHint, GridHints, WaterPosition, CellHints, LoadMode } from './Grid';
import { Vector2i, Vector3i } from './Math';

export enum Content { Nothing, Water, NoWater, Block, Boat, NoBoat, NoBoatWater }
export enum IsTogether { Separate, Together, Zero }

export class PureCell extends CellModel {
    c_left: Content = Content.Nothing;
    c_right: Content = Content.Nothing;
    type: E.CellType = E.CellType.Single;
    last_seen_left: number = 0;
    last_seen_right: number = 0;

    static empty(): PureCell {
        return new PureCell();
    }

    last_seen(corner: E.Corner): number {
        if (E.corner_is_left(corner)) return this.last_seen_left;
        return this.last_seen_right;
    }

    set_last_seen(corner: E.Corner, val: number): void {
        if (this.type === E.CellType.Single) {
            this.last_seen_left = val;
            this.last_seen_right = val;
        } else if (E.corner_is_left(corner)) {
            this.last_seen_left = val;
        } else {
            this.last_seen_right = val;
        }
    }

    _content_at(corner: E.Corner): Content {
        if (this.type === E.CellType.Single) {
            return E.corner_is_left(corner) ? this.c_left : this.c_right;
        }
        switch (corner) {
            case E.Corner.TopLeft: return this.type === E.CellType.IncDiag ? this.c_left : Content.Nothing;
            case E.Corner.TopRight: return this.type === E.CellType.DecDiag ? this.c_right : Content.Nothing;
            case E.Corner.BottomLeft: return this.type === E.CellType.DecDiag ? this.c_left : Content.Nothing;
            case E.Corner.BottomRight: return this.type === E.CellType.IncDiag ? this.c_right : Content.Nothing;
        }
        throw new Error("Invalid corner");
    }

    _content_full(content: Content): boolean {
        return this.type === E.CellType.Single && this.c_left === content && this.c_right === content;
    }

    water_full(): boolean { return this._content_full(Content.Water); }
    water_at(corner: E.Corner): boolean { return this._content_at(corner) === Content.Water; }
    nowater_full(): boolean { return this._content_full(Content.NoWater); }
    noboat_full(): boolean { return this._content_full(Content.NoBoat); }
    noboatwater_full(): boolean { return this._content_full(Content.NoBoatWater); }
    
    nowater_at(corner: E.Corner): boolean {
        const content = this._content_at(corner);
        return content === Content.NoWater || content === Content.NoBoatWater;
    }
    
    noboat_at(corner: E.Corner): boolean {
        const content = this._content_at(corner);
        return content === Content.NoBoat || content === Content.NoBoatWater;
    }
    
    nothing_full(): boolean { return this._content_full(Content.Nothing); }
    nothing_at(corner: E.Corner): boolean { return this._valid_corner(corner) && this._content_at(corner) === Content.Nothing; }
    block_full(): boolean { return this._content_full(Content.Block); }
    block_at(corner: E.Corner): boolean { return this._content_at(corner) === Content.Block; }

    _diag_wall_at(diag: E.Diagonal): boolean {
        return (diag as unknown as E.CellType) === this.type;
    }

    put_content(corner: E.Corner, content: Content, force_no_mix: boolean = false): boolean {
        if (!this._valid_corner(corner)) return false;
        const prev_left = this.c_left;
        const prev_right = this.c_right;
        
        if (!force_no_mix) {
            const current = this._content_at(corner);
            if ((content === Content.NoBoat && current === Content.NoWater) ||
                (content === Content.NoWater && current === Content.NoBoat) ||
                (content === Content.NoBoat && current === Content.NoBoatWater) ||
                (content === Content.NoWater && current === Content.NoBoatWater)) {
                content = Content.NoBoatWater;
            }
        }
        
        if (E.corner_is_left(corner)) {
            if (this.type === E.CellType.Single) this.c_right = content;
            this.c_left = content;
        } else {
            if (this.type === E.CellType.Single) this.c_left = content;
            this.c_right = content;
        }
        return prev_left !== this.c_left || prev_right !== this.c_right;
    }

    put_water(corner: E.Corner, flush_undo?: boolean): number {
        this.put_content(corner, Content.Water);
        return 0; // Overridden
    }

    put_nowater(corner: E.Corner, flush_undo?: boolean, flood?: boolean): boolean {
        return this.put_content(corner, Content.NoWater, false);
    }

    put_noboat(corner: E.Corner, flush_undo?: boolean): boolean {
        return this.put_content(corner, Content.NoBoat, false);
    }

    put_block(corner: E.Corner, flush_undo?: boolean): boolean {
        return this.put_content(corner, Content.Block);
    }

    remove_content(corner: E.Corner, flush_undo?: boolean): void {
        this.put_content(corner, Content.Nothing);
    }
    remove_nowater(corner: E.Corner, flush_undo?: boolean): void { this.remove_content(corner, flush_undo); }
    remove_noboat(corner: E.Corner, flush_undo?: boolean): void { this.remove_content(corner, flush_undo); }
    
    put_wall(wall: E.Walls, flush_undo?: boolean, unsafe_mode?: boolean): boolean { return false; }
    remove_wall(wall: E.Walls, flush_undo?: boolean): boolean { return false; }
    wall_at(wall: E.Walls): boolean { return false; }

    _put_boat(): boolean {
        if (this.type !== E.CellType.Single) return false;
        if (this.c_left !== Content.Nothing && this.c_left !== Content.NoWater && this.c_left !== Content.NoBoat && this.c_left !== Content.NoBoatWater) return false;
        this.c_left = Content.Boat;
        this.c_right = Content.Boat;
        return true;
    }

    has_boat(): boolean { return this._has_boat(); }
    _has_boat(): boolean { return this.c_left === Content.Boat; }
    
    put_boat(flush_undo?: boolean, flood?: boolean): boolean {
        return this._put_boat();
    }
    
    _content_count_from(c: Content, corner: E.Corner): number {
        if (this.type === E.CellType.Single) return this._content_count(c);
        if (!this._valid_corner(corner)) return 0;
        return 0.5 * (E.corner_is_left(corner) ? (c === this.c_left ? 1 : 0) : (c === this.c_right ? 1 : 0));
    }
    
    _content_count(c: Content): number {
        return 0.5 * ((this.c_left === c ? 1 : 0) + (this.c_right === c ? 1 : 0));
    }

    water_count(): number { return this._content_count(Content.Water); }
    nowater_count(): number { return this._content_count(Content.NoWater); }
    nothing_count(): number { return this._content_count(Content.Nothing); }
    block_count(): number { return this._content_count(Content.Block); }
    
    eq(other: PureCell): boolean {
        return this.c_left === other.c_left && this.c_right === other.c_right && this.type === other.type;
    }
    
    clone(): PureCell {
        const cell = new PureCell();
        cell.c_left = this.c_left;
        cell.c_right = this.c_right;
        cell.type = this.type;
        return cell;
    }

    _content_top(): Content { return this._content_side(E.Side.Top); }
    _content_right(): Content { return this.c_right; }
    _content_bottom(): Content { return this._content_side(E.Side.Bottom); }
    _content_left(): Content { return this.c_left; }
    
    _content_side(side: E.Side): Content {
        switch(side) {
            case E.Side.Top: return this.type === E.CellType.DecDiag ? this.c_right : this.c_left;
            case E.Side.Right: return this.c_right;
            case E.Side.Bottom: return this.type === E.CellType.DecDiag ? this.c_left : this.c_right;
            case E.Side.Left: return this.c_left;
        }
    }
    
    _valid_corner(corner: E.Corner): boolean {
        return this.type === E.CellType.Single || (E.corner_to_diag(corner) as unknown as E.CellType) === this.type;
    }
    
    cell_type(): E.CellType { return this.type; }
    
    corners(): E.Corner[] {
        if (this.type === E.CellType.Single) {
            return [E.Corner.TopLeft, E.Corner.TopRight, E.Corner.BottomRight, E.Corner.BottomLeft];
        } else if (this.type === E.CellType.IncDiag) {
            return [E.Corner.TopLeft, E.Corner.BottomRight];
        } else {
            return [E.Corner.TopRight, E.Corner.BottomLeft];
        }
    }
    
    waters(): E.Waters[] {
        if (this.type === E.CellType.Single) return [E.Waters.Single];
        return this.corners() as unknown as E.Waters[];
    }
    
    water_would_flood_how_many(corner: E.Corner): number { return 0; }
    water_would_flood_which(corner: E.Corner, in_area?: any): WaterPosition[] { return []; }
    boat_possible(disallow_nowater_below?: boolean, only_permanent_content?: boolean): boolean { return false; }
    boat_would_flood_which(): WaterPosition[] { return []; }
    nowater_would_flood_how_many(corner: E.Corner): number { return 0; }
    
    add_cell_hints(flush_undo?: boolean): boolean { return false; }
    rem_cell_hints(flush_undo?: boolean): boolean { return false; }
    hints(): CellHints { return new CellHints(); }
    hints_status(): E.HintStatus { return E.HintStatus.Normal; }
}

export class CellWithLoc extends CellModel {
    i: number;
    j: number;
    grid: GridImpl;

    constructor(i: number, j: number, grid: GridImpl) {
        super();
        this.i = i;
        this.j = j;
        this.grid = grid;
    }

    pure(): PureCell { return this.grid._pure_cell(this.i, this.j); }
    water_full(): boolean { return this.pure().water_full(); }
    water_at(corner: E.Corner): boolean { return this.pure().water_at(corner); }
    nowater_full(): boolean { return this.pure().nowater_full(); }
    noboat_full(): boolean { return this.pure().noboat_full(); }
    noboatwater_full(): boolean { return this.pure().noboatwater_full(); }
    nowater_at(corner: E.Corner): boolean { return this.pure().nowater_at(corner); }
    noboat_at(corner: E.Corner): boolean { return this.pure().noboat_at(corner); }
    nothing_full(): boolean { return this.pure().nothing_full(); }
    nothing_at(corner: E.Corner): boolean { return this.pure().nothing_at(corner); }
    block_full(): boolean { return this.pure().block_full(); }
    block_at(corner: E.Corner): boolean { return this.pure().block_at(corner); }

    wall_at(wall: E.Walls): boolean {
        switch (wall) {
            case E.Walls.Top:
            case E.Walls.Right:
            case E.Walls.Bottom:
            case E.Walls.Left:
                return this.grid.wall_at(this.i, this.j, wall as unknown as E.Side);
            case E.Walls.IncDiag:
            case E.Walls.DecDiag:
                return this.pure()._diag_wall_at(wall as unknown as E.Diagonal);
        }
        return false;
    }

    put_water(corner: E.Corner, flush_undo: boolean = true): number {
        if (!this.pure().water_at(corner)) {
            const dfs = new AddWaterDfs(this.grid, this.i);
            this.grid.last_seen++;
            dfs.flood(this.i, this.j, corner);
            // After dropping water, re-flood everything from the top to ensure water falls properly
            this.grid.flood_all();
        }
        return 1;
    }
    
    put_nowater(corner: E.Corner, flush_undo?: boolean, flood?: boolean): boolean {
        const pure = this.pure();
        if (pure.water_at(corner)) {
            this.remove_content(corner, false);
        }
        const res = pure.put_nowater(corner, false);
        if (flood) {
            // Note: flood is passed as autoFloodAir
            const dfs = new AddNoWaterDfs(this.grid, flood);
            this.grid.last_seen++;
            dfs.flood(this.i, this.j, corner);
        }
        return res;
    }
    
    put_noboat(corner: E.Corner, flush_undo?: boolean): boolean {
        const pure = this.pure();
        if (pure.water_at(corner)) pure.remove_content(corner, false);
        const res = pure.put_noboat(corner, false);
        return res;
    }
    
    put_block(corner: E.Corner, flush_undo?: boolean): boolean { return this.pure().put_block(corner); }
    remove_content(corner: E.Corner, flush_undo?: boolean, flood_air?: boolean): void {
        if (this.pure().water_at(corner)) {
            const dfs = new RemoveWaterDfs(this.grid);
            this.grid.last_seen++;
            dfs.flood(this.i, this.j, corner);
            this.grid.flood_all();
        } else if (this.pure().nowater_at(corner) && flood_air) {
            const dfs = new RemoveNoWaterDfs(this.grid);
            this.grid.last_seen++;
            dfs.flood(this.i, this.j, corner);
        } else {
            this.pure().remove_content(corner);
        }
    }
    remove_nowater(corner: E.Corner, flush_undo?: boolean): void { this.pure().remove_nowater(corner); }
    remove_noboat(corner: E.Corner, flush_undo?: boolean): void { this.pure().remove_noboat(corner); }
    
    put_wall(wall: E.Walls, flush_undo?: boolean, unsafe_mode?: boolean): boolean { return false; }
    remove_wall(wall: E.Walls, flush_undo?: boolean): boolean { return false; }
    
    put_boat(flush_undo?: boolean, flood?: boolean): boolean { return this.pure().put_boat(flush_undo, flood); }
    has_boat(): boolean { return this.pure().has_boat(); }
    
    cell_type(): E.CellType { return this.pure().type; }
    corners(): E.Corner[] { return this.pure().corners(); }
    waters(): E.Waters[] { return this.pure().waters(); }
    
    water_would_flood_how_many(corner: E.Corner): number { return 0; }
    water_would_flood_which(corner: E.Corner, in_area?: any): WaterPosition[] { return []; }
    boat_possible(disallow_nowater_below?: boolean, only_permanent_content?: boolean): boolean { return false; }
    boat_would_flood_which(): WaterPosition[] { return []; }
    nowater_would_flood_how_many(corner: E.Corner): number { return 0; }
    
    add_cell_hints(flush_undo?: boolean): boolean { return false; }
    rem_cell_hints(flush_undo?: boolean): boolean { return false; }
    hints(): CellHints { return new CellHints(); }
    hints_status(): E.HintStatus { return E.HintStatus.Normal; }
}


export class Dfs {
    grid: GridImpl;
    constructor(grid: GridImpl) { this.grid = grid; }
    
    flood(i: number, j: number, corner: E.Corner): void {
        const cell = this.grid._pure_cell(i, j);
        if (cell.last_seen(corner) >= this.grid.last_seen) return;
        if (!this._cell_logic(i, j, corner, cell)) return;
        cell.set_last_seen(corner, this.grid.last_seen);
        
        const isLeft = E.corner_is_left(corner);
        const isTop = E.corner_is_top(corner);
        
        // Left
        if (!this.grid.wall_at(i, j, E.Side.Left) && !(cell.type !== E.CellType.Single && !isLeft) && j - 1 >= 0) {
            const nextCell = this.grid._pure_cell(i, j - 1);
            this.flood(i, j - 1, E.diag_to_corner(nextCell.type, E.Side.Right));
        }
        // Right
        if (!this.grid.wall_at(i, j, E.Side.Right) && !(cell.type !== E.CellType.Single && isLeft) && j + 1 < this.grid.cols()) {
            const nextCell = this.grid._pure_cell(i, j + 1);
            this.flood(i, j + 1, E.diag_to_corner(nextCell.type, E.Side.Left));
        }
        // Down
        if (!this.grid.wall_at(i, j, E.Side.Bottom) && !(cell.type !== E.CellType.Single && isTop) && i + 1 < this.grid.rows() && this._can_go_down(i, j)) {
            const nextCell = this.grid._pure_cell(i + 1, j);
            this.flood(i + 1, j, E.diag_to_corner(nextCell.type, E.Side.Top));
        }
        // Up
        if (!this.grid.wall_at(i, j, E.Side.Top) && !(cell.type !== E.CellType.Single && !isTop) && i - 1 >= 0 && this._can_go_up(i, j)) {
            const nextCell = this.grid._pure_cell(i - 1, j);
            this.flood(i - 1, j, E.diag_to_corner(nextCell.type, E.Side.Bottom));
        }
    }
    
    _cell_logic(i: number, j: number, corner: E.Corner, cell: PureCell): boolean { return true; }
    _can_go_up(i: number, j: number): boolean { return true; }
    _can_go_down(i: number, j: number): boolean { return true; }
}

export class AddWaterDfs extends Dfs {
    min_i: number;
    constructor(grid: GridImpl, min_i: number) {
        super(grid);
        this.min_i = min_i;
    }
    _cell_logic(i: number, j: number, corner: E.Corner, cell: PureCell): boolean {
        const content = cell._content_at(corner);
        if (content === Content.Block) return false;
        cell.put_content(corner, Content.Water);
        return true;
    }
    _can_go_up(i: number, j: number): boolean { return i - 1 >= this.min_i; }
    _can_go_down(i: number, j: number): boolean { return true; }
}

export class RemoveWaterDfs extends Dfs {
    constructor(grid: GridImpl) {
        super(grid);
    }
    _cell_logic(i: number, j: number, corner: E.Corner, cell: PureCell): boolean {
        const content = cell._content_at(corner);
        if (content === Content.Water || content === Content.Boat) {
            cell.remove_content(corner);
            return content === Content.Water;
        }
        return false;
    }
    _can_go_up(i: number, j: number): boolean { return true; }
    _can_go_down(i: number, j: number): boolean { return false; }
}

export class RemoveNoWaterDfs extends Dfs {
    constructor(grid: GridImpl) {
        super(grid);
    }
    _cell_logic(i: number, j: number, corner: E.Corner, cell: PureCell): boolean {
        const content = cell._content_at(corner);
        if (content === Content.NoWater || content === Content.NoBoatWater) {
            cell.remove_content(corner);
            return content === Content.NoWater;
        }
        return false;
    }
    _can_go_up(i: number, j: number): boolean { return false; }
    _can_go_down(i: number, j: number): boolean { return true; }
}

export class AddNoWaterDfs extends Dfs {
    autoFloodAir: boolean;
    constructor(grid: GridImpl, autoFloodAir: boolean) {
        super(grid);
        this.autoFloodAir = autoFloodAir;
    }
    _cell_logic(i: number, j: number, corner: E.Corner, cell: PureCell): boolean {
        const content = cell._content_at(corner);
        if (content === Content.Block || content === Content.Boat) return false;
        cell.put_nowater(corner, false, false);
        return true;
    }
    _can_go_up(i: number, j: number): boolean { return this.autoFloodAir; }
    _can_go_down(i: number, j: number): boolean { return false; }
}

import type { GridModelData } from '../model/GridData';

export class GridImpl extends GridModel {
    n: number = 0;
    m: number = 0;
    pure_cells: PureCell[][] = [];
    _row_hints: LineHint[] = [];
    _col_hints: LineHint[] = [];
    _grid_hints: GridHints = new GridHints();
    wall_bottom: boolean[][] = [];
    wall_right: boolean[][] = [];

    static load_from_grid_data(data: GridModelData): GridImpl {
        const rows = data.cells.length;
        const cols = data.cells[0]?.length ?? 0;
        const grid = new GridImpl(rows, cols);
        grid._grid_hints = data.grid_hints as GridHints;
        
        for (let i = 0; i < rows; i++) {
            grid._row_hints[i] = data.row_hints[i] as LineHint;
            for (let j = 0; j < cols; j++) {
                const pure = grid.pure_cells[i][j];
                const rawCell = data.cells[i][j];
                pure.c_left = rawCell.c_left;
                pure.c_right = rawCell.c_right;
                pure.type = rawCell.type as unknown as E.CellType;
                
                if (i < rows - 1) grid.wall_bottom[i][j] = data.wall_bottom[i][j];
                if (j < cols - 1) grid.wall_right[i][j] = data.wall_right[i][j];
            }
        }
        for (let j = 0; j < cols; j++) {
            grid._col_hints[j] = data.col_hints[j] as LineHint;
        }
        
        // Re-flood imported water
        grid.flood_all();
        return grid;
    }

    to_grid_data(): GridModelData {
        const cells: any[][] = [];
        for (let i = 0; i < this.n; i++) {
            const row: any[] = [];
            for (let j = 0; j < this.m; j++) {
                const pure = this.pure_cells[i][j];
                row.push({
                    c_left: pure.c_left,
                    c_right: pure.c_right,
                    type: pure.type
                });
            }
            cells.push(row);
        }
        return {
            version: 1,
            cells,
            cell_hints: [],
            row_hints: this._row_hints,
            col_hints: this._col_hints,
            wall_bottom: this.wall_bottom,
            wall_right: this.wall_right,
            grid_hints: this._grid_hints
        };
    }

    constructor(n: number, m: number) {
        super();
        this.setup(n, m);
    }

    setup(n: number, m: number): void {
        this.n = n;
        this.m = m;
        this.pure_cells = [];
        this.wall_right = [];
        this.wall_bottom = [];
        this._row_hints = [];
        this._col_hints = [];

        for (let i = 0; i < n; i++) {
            const row: PureCell[] = [];
            const row_down: boolean[] = [];
            const row_right: boolean[] = [];
            for (let j = 0; j < m; j++) {
                row.push(PureCell.empty());
                row_down.push(false);
                if (j < m - 1) row_right.push(false);
            }
            this.pure_cells.push(row);
            this.wall_right.push(row_right);
            if (i < n - 1) this.wall_bottom.push(row_down);
            this._row_hints.push(new LineHint());
        }
        for (let j = 0; j < m; j++) {
            this._col_hints.push(new LineHint());
        }
    }

    _pure_cell(i: number, j: number): PureCell {
        return this.pure_cells[i][j];
    }

    get_cell(i: number, j: number): CellModel {
        return new CellWithLoc(i, j, this);
    }

    rows(): number { return this.n; }
    cols(): number { return this.m; }

    wall_at(i: number, j: number, side: E.Side): boolean {
        switch (side) {
            case E.Side.Top: return i === 0 || this.wall_bottom[i - 1][j];
            case E.Side.Bottom: return i === this.n - 1 || this.wall_bottom[i][j];
            case E.Side.Left: return j === 0 || this.wall_right[i][j - 1];
            case E.Side.Right: return j === this.m - 1 || this.wall_right[i][j];
        }
        return false;
    }

    // Stub out remaining required methods
    put_wall_from_idx(i1: number, j1: number, i2: number, j2: number, flush_undo?: boolean): boolean { return false; }
    remove_wall_from_idx(i1: number, j1: number, i2: number, j2: number, flush_undo?: boolean): boolean { return false; }
    row_hints(): LineHint[] { return this._row_hints; }
    col_hints(): LineHint[] { return this._col_hints; }
    add_row(flush_undo?: boolean): void {}
    rem_row(flush_undo?: boolean): void {}
    add_col(flush_undo?: boolean): void {}
    rem_col(flush_undo?: boolean): void {}
    get_expected_boats(): number { return this._grid_hints.total_boats; }
    get_expected_waters(): number { return this._grid_hints.total_water; }
    
    count_boats(): number {
        let c = 0;
        for (let i = 0; i < this.n; i++) {
            for (let j = 0; j < this.m; j++) {
                if (this._pure_cell(i, j).has_boat()) c++;
            }
        }
        return c;
    }
    
    count_waters(): number {
        let c = 0;
        for (let i = 0; i < this.n; i++) {
            for (let j = 0; j < this.m; j++) c += this._pure_cell(i, j).water_count();
        }
        return c;
    }

    count_water_row(i: number): number {
        let c = 0;
        for (let j = 0; j < this.m; j++) c += this._pure_cell(i, j).water_count();
        return c;
    }

    count_water_col(j: number): number {
        let c = 0;
        for (let i = 0; i < this.n; i++) c += this._pure_cell(i, j).water_count();
        return c;
    }
    
    count_boat_row(i: number): number {
        let c = 0;
        for (let j = 0; j < this.m; j++) if (this._pure_cell(i, j).has_boat()) c++;
        return c;
    }

    count_boat_col(j: number): number {
        let c = 0;
        for (let i = 0; i < this.n; i++) if (this._pure_cell(i, j).has_boat()) c++;
        return c;
    }

    _hint_statusf(count: number, hint: number): E.HintStatus {
        if (hint === -1 || count === hint) return E.HintStatus.Satisfied;
        if (count > hint) return E.HintStatus.Wrong;
        return E.HintStatus.Normal;
    }

    all_boats_hint_status(): E.HintStatus { return this._hint_statusf(this.count_boats(), this.get_expected_boats()); }
    all_waters_hint_status(): E.HintStatus { return this._hint_statusf(this.count_waters(), this.get_expected_waters()); }
    
    merge_status(s1: E.HintStatus, s2: E.HintStatus): E.HintStatus {
        if (s1 === E.HintStatus.Wrong || s2 === E.HintStatus.Wrong) return E.HintStatus.Wrong;
        if (s1 === E.HintStatus.Normal || s2 === E.HintStatus.Normal) return E.HintStatus.Normal;
        return E.HintStatus.Satisfied;
    }

    get_row_hint_status(i: number, hint_content: E.HintContent): E.HintStatus {
        const hint = this._row_hints[i];
        if (hint_content === E.HintContent.Water) return this._hint_statusf(this.count_water_row(i), hint.water_count);
        return this._hint_statusf(this.count_boat_row(i), hint.boat_count);
    }

    get_col_hint_status(j: number, hint_content: E.HintContent): E.HintStatus {
        const hint = this._col_hints[j];
        if (hint_content === E.HintContent.Water) return this._hint_statusf(this.count_water_col(j), hint.water_count);
        return this._hint_statusf(this.count_boat_col(j), hint.boat_count);
    }

    all_hints_status(): E.HintStatus {
        let s = E.HintStatus.Satisfied;
        s = this.merge_status(s, this.all_boats_hint_status());
        if (s === E.HintStatus.Wrong) return s;
        s = this.merge_status(s, this.all_waters_hint_status());
        if (s === E.HintStatus.Wrong) return s;
        // Aquarium logic skipped for now
        for (let i = 0; i < this.n; i++) {
            s = this.merge_status(s, this.get_row_hint_status(i, E.HintContent.Water));
            s = this.merge_status(s, this.get_row_hint_status(i, E.HintContent.Boat));
            if (s === E.HintStatus.Wrong) return s;
        }
        for (let j = 0; j < this.m; j++) {
            s = this.merge_status(s, this.get_col_hint_status(j, E.HintContent.Water));
            s = this.merge_status(s, this.get_col_hint_status(j, E.HintContent.Boat));
            if (s === E.HintStatus.Wrong) return s;
        }
        return s;
    }

    check_complete(): boolean {
        for (let i = 0; i < this.n; i++) {
            for (let j = 0; j < this.m; j++) {
                const c = this._pure_cell(i, j);
                if (c.c_left === Content.Nothing || c.c_right === Content.Nothing) return false;
            }
        }
        return true;
    }

    are_hints_satisfied(check_complete?: boolean): boolean {
        if (check_complete && !this.check_complete()) return false;
        return this.all_hints_status() === E.HintStatus.Satisfied;
    }

    is_any_hint_broken(): boolean {
        return this.all_hints_status() === E.HintStatus.Wrong;
    }

    count_water_adj(i: number, j: number): number { return 0; }
    count_nothing_adj(i: number, j: number): number { return 0; }
    grid_hints(): GridHints { return this._grid_hints; }
    all_aquarium_counts(): Record<number, number> { return {}; }
    aquarium_hints_status(): E.HintStatus { return E.HintStatus.Satisfied; }
    load_from_str(s: string, load_mode?: LoadMode): void {}
    to_str(): string { return ""; }
    undo(skip_empty?: boolean): boolean { return false; }
    redo(skip_empty?: boolean): boolean { return false; }
    push_empty_undo(): void {}

    last_seen: number = 0;
    
    flood_all(flush_undo?: boolean): boolean {
        this.last_seen++;
        for (let i = 0; i < this.n; i++) {
            for (let j = 0; j < this.m; j++) {
                const cell = this._pure_cell(i, j);
                for (const corner of cell.corners()) {
                    if (cell.water_at(corner) && cell.last_seen(corner) < this.last_seen) {
                        const dfs = new AddWaterDfs(this, i);
                        dfs.flood(i, j, corner);
                    }
                }
            }
        }
        return true;
    }
    
    flood_nowater(flush_undo?: boolean): boolean { return false; }
    clear_content(): void {}
    clear_all(): void {}
    editor_mode(): boolean { return false; }
    force_editor_mode(b?: boolean): void {}
    set_auto_update_hints(b: boolean): void {}
    export_data(): any { return {}; }
    is_empty(): boolean { return false; }
    copy_to_clipboard(): void {}
    merge_last_undo(): void {}
    count_blocks(): number { return 0; }
    prettify_hints(is_procedurally_generated: boolean): void {}
    any_schrodinger_boats(): boolean { return false; }
    is_equal_solution(): boolean { return false; }
    mirror_horizontal(): void {}
    mirror_vertical(): void {}
    rotate_clockwise(): void {}
    rotate_counter(): void {}
}