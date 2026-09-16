// src/engine/GridImpl.ts

import { E } from './E';
import { GridModel, CellModel, LineHint, GridHints, WaterPosition, CellHints, LoadMode } from './Grid';
import { Vector2i, Vector3i, Rect2i } from './Math';
import { GridExporter } from './GridExporter';
import type { GridModelData } from '../model/GridData';

export enum Content { Nothing = 0, Water = 1, NoWater = 2, Block = 3, Boat = 4, NoBoat = 5, NoBoatWater = 6 }
export enum IsTogether { Separate, Together, Zero }

export class Ij2 {
    static corner(grid: GridImpl, v: Vector2i): E.Corner {
        return grid._pure_cell(v.x, Math.floor(v.y / 2)).corners()[v.y & 1];
    }

    static waters(grid: GridImpl, v: Vector2i): E.Waters {
        return grid._pure_cell(v.x, Math.floor(v.y / 2)).waters()[v.y & 1];
    }

    static size(grid: GridImpl, v: Vector2i): number {
        return E.waters_size(Ij2.waters(grid, v));
    }

    static content(grid: GridImpl, v: Vector2i): Content {
        const c = grid._pure_cell(v.x, Math.floor(v.y / 2));
        return (v.y & 1) === 0 ? c.c_left : c.c_right;
    }
}

export abstract class Change {
    abstract undo(grid: GridImpl): Change;
}

export class CellChange extends Change {
    i: number;
    j: number;
    prev_cell: PureCell;

    constructor(i: number, j: number, prev_cell: PureCell) {
        super();
        this.i = i;
        this.j = j;
        this.prev_cell = prev_cell;
    }

    undo(grid: GridImpl): Change {
        const new_cell = grid.pure_cells[this.i][this.j].clone();
        grid.pure_cells[this.i][this.j] = this.prev_cell;
        this.prev_cell = new_cell;
        return this;
    }
}

export class CellHintsChange extends Change {
    i: number;
    j: number;
    was_present: boolean;

    constructor(i: number, j: number, was_present: boolean) {
        super();
        this.i = i;
        this.j = j;
        this.was_present = was_present;
    }

    undo(grid: GridImpl): Change {
        (grid.get_cell(this.i, this.j) as CellWithLoc)._set_cell_hints(this.was_present);
        this.was_present = !this.was_present;
        return this;
    }
}

export class WallChange extends Change {
    i: number;
    j: number;
    side: E.Side;
    present: boolean;

    constructor(i: number, j: number, side: E.Side, present: boolean) {
        super();
        this.i = i;
        this.j = j;
        this.side = side;
        this.present = present;
    }

    undo(grid: GridImpl): Change {
        const now_present = grid.wall_at(this.i, this.j, this.side);
        grid._change_wall(this.i, this.j, this.side, this.present);
        this.present = now_present;
        return this;
    }
}

export class AddRowChange extends Change {
    undo(grid: GridImpl): Change {
        return grid._do_rem_row();
    }
}

export class RemRowChange extends Change {
    prev_row: PureCell[];
    prev_hints: (CellHints | null)[];
    prev_wall_bottom: boolean[];
    prev_wall_right: boolean[];
    prev_hint: LineHint;

    constructor(prev_row: PureCell[], prev_hints: (CellHints | null)[], prev_wall_bottom: boolean[], prev_wall_right: boolean[], prev_hint: LineHint) {
        super();
        this.prev_row = prev_row;
        this.prev_hints = prev_hints;
        this.prev_wall_bottom = prev_wall_bottom;
        this.prev_wall_right = prev_wall_right;
        this.prev_hint = prev_hint;
    }

    undo(grid: GridImpl): Change {
        return grid._do_add_row(this.prev_row, this.prev_hints, this.prev_wall_bottom, this.prev_wall_right, this.prev_hint);
    }
}

export class AddColChange extends Change {
    undo(grid: GridImpl): Change {
        return grid._do_rem_col();
    }
}

export class RemColChange extends Change {
    prev_col: PureCell[];
    prev_hints: (CellHints | null)[];
    prev_wall_bottom: boolean[];
    prev_wall_right: boolean[];
    prev_hint: LineHint;

    constructor(prev_col: PureCell[], prev_hints: (CellHints | null)[], prev_wall_bottom: boolean[], prev_wall_right: boolean[], prev_hint: LineHint) {
        super();
        this.prev_col = prev_col;
        this.prev_hints = prev_hints;
        this.prev_wall_bottom = prev_wall_bottom;
        this.prev_wall_right = prev_wall_right;
        this.prev_hint = prev_hint;
    }

    undo(grid: GridImpl): Change {
        return grid._do_add_col(this.prev_col, this.prev_hints, this.prev_wall_bottom, this.prev_wall_right, this.prev_hint);
    }
}

export class Changes {
    changes: Change[];
    constructor(changes: Change[] = []) {
        this.changes = changes;
    }
}

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

    put_water(corner: E.Corner, flush_undo?: boolean): number { return this.put_content(corner, Content.Water) ? 1 : 0; }
    put_nowater(corner: E.Corner, force_no_mix: boolean = false): boolean { return this.put_content(corner, Content.NoWater, force_no_mix); }
    put_noboat(corner: E.Corner, force_no_mix: boolean = false): boolean { return this.put_content(corner, Content.NoBoat, force_no_mix); }
    put_block(corner: E.Corner): boolean { return this.put_content(corner, Content.Block); }
    put_nothing(corner: E.Corner): boolean { return this.put_content(corner, Content.Nothing); }

    remove_content(corner: E.Corner): void { this.put_content(corner, Content.Nothing); }
    remove_nowater(corner: E.Corner): void { this.remove_content(corner); }
    remove_noboat(corner: E.Corner): void { this.remove_content(corner); }

    put_wall(wall: E.Walls): boolean { return false; }
    remove_wall(wall: E.Walls): boolean { return false; }
    wall_at(wall: E.Walls): boolean { return false; }

    _put_boat(): boolean {
        if (this.type !== E.CellType.Single) return false;
        if (this.c_left !== Content.Nothing && this.c_left !== Content.NoWater &&
            this.c_left !== Content.NoBoat && this.c_left !== Content.NoBoatWater) {
            return false;
        }
        this.c_left = Content.Boat;
        this.c_right = Content.Boat;
        return true;
    }

    has_boat(): boolean { return this._has_boat(); }
    _has_boat(): boolean { return this.c_left === Content.Boat; }

    put_boat(): boolean {
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
        switch (side) {
            case E.Side.Top: return this.type === E.CellType.DecDiag ? this.c_right : this.c_left;
            case E.Side.Right: return this.c_right;
            case E.Side.Bottom: return this.type === E.CellType.DecDiag ? this.c_left : this.c_right;
            case E.Side.Left: return this.c_left;
        }
    }

    _valid_corner(corner: E.Corner): boolean {
        return this.type === E.CellType.Single || (E.corner_to_diag(corner) as unknown as E.CellType) === this.type;
    }

    _change_diag_wall(diag: E.Diagonal, new_val: boolean): void {
        if (new_val) {
            if (this._has_boat() || (this.c_left !== this.c_right && this.type !== E.CellType.Single && (this.type as unknown as E.Diagonal) !== diag)) {
                this.c_left = Content.Nothing;
                this.c_right = Content.Nothing;
            }
            this.type = diag as unknown as E.CellType;
        } else {
            this.type = E.CellType.Single;
        }
    }

    cell_type(): E.CellType { return this.type; }

    corners(): E.Corner[] {
        switch (this.type) {
            case E.CellType.Single:
                return [E.Corner.TopLeft, E.Corner.TopRight, E.Corner.BottomRight, E.Corner.BottomLeft];
            case E.CellType.DecDiag:
                return [E.Corner.BottomLeft, E.Corner.TopRight];
            case E.CellType.IncDiag:
                return [E.Corner.TopLeft, E.Corner.BottomRight];
        }
    }

    waters(): E.Waters[] {
        switch (this.type) {
            case E.CellType.Single:
                return [E.Waters.Single];
            case E.CellType.DecDiag:
                return [E.Waters.BottomLeft, E.Waters.TopRight];
            case E.CellType.IncDiag:
                return [E.Waters.TopLeft, E.Waters.BottomRight];
        }
    }

    mirror_horizontal(): void {
        const new_right = this.c_left;
        this.c_left = this.c_right;
        this.c_right = new_right;
        if (this.type === E.CellType.IncDiag) {
            this.type = E.CellType.DecDiag;
        } else if (this.type === E.CellType.DecDiag) {
            this.type = E.CellType.IncDiag;
        }
    }

    rotate_clock(): void {
        if (this.type === E.CellType.IncDiag) {
            this.mirror_horizontal();
        } else if (this.type === E.CellType.DecDiag) {
            this.type = E.CellType.IncDiag;
        }
    }

    equal(other: PureCell): boolean {
        return this.eq(other);
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
        if (!this.grid.is_corner_partially_valid(Content.Water, this.i, this.j, corner)) {
            return 0.0;
        }
        let added_waters = 0.0;
        if (!this.water_at(corner)) {
            const dfs = this.grid._flood_water(this.i, this.j, corner, true) as AddWaterDfs;
            added_waters = dfs.added_waters;
            this.grid._push_undo_changes(dfs.changes, flush_undo);
        }
        this.grid.maybe_update_hints();
        return added_waters;
    }

    put_block(corner: E.Corner, flush_undo: boolean = true): boolean {
        if (!this.grid.editor_mode()) return false;
        if (flush_undo) this.grid.push_empty_undo();
        const change = new CellChange(this.i, this.j, this.pure().clone());
        if (this.pure().put_block(corner)) {
            this.grid._push_undo_changes([change], false);
            this.grid.maybe_update_hints();
            return true;
        }
        return false;
    }

    put_nowater(corner: E.Corner, flush_undo: boolean = true, flood: boolean = false, force_no_mix: boolean = false): boolean {
        if (flush_undo) this.grid.push_empty_undo();
        if (!this.grid.is_corner_partially_valid(Content.NoWater, this.i, this.j, corner)) {
            return false;
        }
        if (this.water_at(corner)) {
            this.remove_content(corner, false);
        }
        const changes: Change[] = [new CellChange(this.i, this.j, this.pure().clone())];
        if (this.pure().put_nowater(corner, force_no_mix)) {
            if (flood) {
                const dfs = new AddNoWaterDfs(this.grid);
                dfs.flood(this.i, this.j, corner);
                changes.push(...dfs.changes);
            }
            this.grid._push_undo_changes(changes, false);
        }
        this.grid.maybe_update_hints();
        return true;
    }

    put_noboat(corner: E.Corner, flush_undo: boolean = true, force_no_mix: boolean = false): boolean {
        if (flush_undo) this.grid.push_empty_undo();
        if (!this.grid.is_corner_partially_valid(Content.NoBoat, this.i, this.j, corner)) {
            return false;
        }
        if (this.water_at(corner)) {
            this.remove_content(corner, false);
        }
        const changes: Change[] = [new CellChange(this.i, this.j, this.pure().clone())];
        if (this.pure().put_noboat(corner, force_no_mix)) {
            this.grid._push_undo_changes(changes, false);
        }
        this.grid.maybe_update_hints();
        return true;
    }

    remove_content(corner: E.Corner, flush_undo: boolean = true, flood_air: boolean = false): void {
        if (this.block_at(corner) && !this.grid.editor_mode()) {
            return;
        }
        if (flush_undo) this.grid.push_empty_undo();
        const changes: Change[] = [];
        if (this.water_at(corner)) {
            changes.push(...this.grid._flood_water(this.i, this.j, corner, false).changes);
        } else if (this.pure().nowater_at(corner) && flood_air) {
            const dfs = new RemoveNoWaterDfs(this.grid);
            dfs.flood(this.i, this.j, corner);
            changes.push(...dfs.changes);
        }
        const change = new CellChange(this.i, this.j, this.pure().clone());
        if (this.pure().put_nothing(corner)) {
            changes.push(change);
            this.grid._push_undo_changes(changes, false);
            if (change.prev_cell.block_at(corner)) {
                this.grid.flood_all(false);
            }
        } else {
            this.grid._push_undo_changes(changes, false);
        }
        this.grid.maybe_update_hints();
    }

    remove_nowater(corner: E.Corner, flush_undo: boolean = true): void {
        if (this.pure()._content_at(corner) !== Content.NoBoatWater) {
            return this.remove_content(corner, flush_undo);
        }
        this.put_noboat(corner, flush_undo, true);
    }

    remove_noboat(corner: E.Corner, flush_undo: boolean = true): void {
        if (this.pure()._content_at(corner) !== Content.NoBoatWater) {
            return this.remove_content(corner, flush_undo);
        }
        this.put_nowater(corner, flush_undo, false, true);
    }

    _change_wall(wall: E.Walls, new_val: boolean, flush_undo: boolean, unsafe_mode: boolean): void {
        switch (wall) {
            case E.Walls.Top:
            case E.Walls.Left:
            case E.Walls.Right:
            case E.Walls.Bottom: {
                const c = new WallChange(this.i, this.j, wall as unknown as E.Side, this.grid.wall_at(this.i, this.j, wall as unknown as E.Side));
                this.grid._change_wall(this.i, this.j, wall as unknown as E.Side, new_val);
                this.grid._push_undo_changes([c], flush_undo);
                break;
            }
            case E.Walls.DecDiag:
            case E.Walls.IncDiag: {
                const c = new CellChange(this.i, this.j, this.pure().clone());
                this.pure()._change_diag_wall(wall as unknown as E.Diagonal, new_val);
                this.grid._push_undo_changes([c], flush_undo);
                break;
            }
        }
        if (unsafe_mode) return;
        if (new_val) {
            this.grid.fix_invalid_boats(false);
        } else {
            this.grid.flood_all(false);
        }
        this.grid.validate();
        this.grid.maybe_update_hints();
    }

    put_wall(wall: E.Walls, flush_undo: boolean = true, unsafe_mode: boolean = false): boolean {
        this._change_wall(wall, true, flush_undo, unsafe_mode);
        return true;
    }

    remove_wall(wall: E.Walls, flush_undo: boolean = true): boolean {
        this._change_wall(wall, false, flush_undo, false);
        return true;
    }

    put_boat(flush_undo: boolean = true, flood: boolean = false): boolean {
        if (flush_undo) this.grid.push_empty_undo();
        if (this.wall_at(E.Walls.Bottom) || this.pure().cell_type() !== E.CellType.Single) {
            return false;
        }
        if (!this.grid.is_corner_partially_valid(Content.Boat, this.i, this.j, E.Corner.TopRight)) {
            return false;
        }
        if (this.i + 1 >= this.grid.rows()) return false;
        const c = this.grid.get_cell(this.i + 1, this.j) as CellWithLoc;
        if (c.pure()._content_top() !== Content.Water) {
            if (!c.put_water(E.diag_to_corner(c.cell_type(), E.Side.Top), false)) {
                return false;
            }
        }
        if (this.water_at(E.Corner.TopLeft)) {
            this.remove_content(E.Corner.TopLeft, false);
        }
        const changes: Change[] = [new CellChange(this.i, this.j, this.pure().clone())];
        if (this.pure()._put_boat()) {
            if (flood) {
                const dfs = new AddNoWaterDfs(this.grid);
                dfs.flood(this.i, this.j, E.Corner.TopLeft);
                changes.push(...dfs.changes);
            }
            this.grid._push_undo_changes(changes, false);
            this.grid.maybe_update_hints();
            return true;
        }
        return false;
    }

    has_boat(): boolean { return this.pure().has_boat(); }
    cell_type(): E.CellType { return this.pure().cell_type(); }
    corners(): E.Corner[] { return this.pure().corners(); }
    waters(): E.Waters[] { return this.pure().waters(); }

    water_would_flood_how_many(corner: E.Corner): number {
        if (this.water_at(corner)) return 0.0;
        const dfs = new AddWaterDfs(this.grid, this.i);
        dfs.dry_run = true;
        dfs.flood(this.i, this.j, corner);
        return dfs.added_waters;
    }

    water_would_flood_which(corner: E.Corner, in_area?: any): WaterPosition[] {
        if (this.water_at(corner)) return [];
        const dfs = new AddWaterDfs(this.grid, this.i, in_area);
        dfs.dry_run = true;
        dfs.flood(this.i, this.j, corner);
        return dfs.water_locs;
    }

    boat_possible(disallow_nowater_below: boolean = true, only_permanent_content: boolean = false): boolean {
        if (this.cell_type() !== E.CellType.Single || this.block_full() || this.wall_at(E.Walls.Bottom)) {
            return false;
        }
        if (!only_permanent_content && this.water_full()) {
            return false;
        }
        if (this.i + 1 >= this.grid.rows()) return false;
        const below = this.grid._pure_cell(this.i + 1, this.j)._content_top();
        if (only_permanent_content) {
            return below !== Content.Block;
        }
        if (!disallow_nowater_below && (below === Content.NoBoatWater || below === Content.NoWater)) {
            return true;
        }
        return below === Content.Water || below === Content.Nothing || below === Content.NoBoat;
    }

    boat_would_flood_which(): WaterPosition[] {
        if (this.boat_possible(false)) {
            const c = this.grid.get_cell(this.i + 1, this.j) as CellWithLoc;
            return c.water_would_flood_which(E.diag_to_corner(c.cell_type(), E.Side.Top));
        } else {
            return [];
        }
    }

    nowater_would_flood_how_many(corner: E.Corner): number {
        if (!this.nothing_at(corner)) return 0.0;
        const dfs = new AddNoWaterDfs(this.grid);
        dfs.dry_run = true;
        dfs.flood(this.i, this.j, corner);
        return dfs.added_nowater;
    }

    _has_boat_invalid_pos(): boolean {
        return this.has_boat() && (this.wall_at(E.Walls.Bottom) || this.cell_type() !== E.CellType.Single ||
            this.i + 1 >= this.grid.rows() || (this.grid.get_cell(this.i + 1, this.j) as CellWithLoc).pure()._content_top() !== Content.Water);
    }

    _set_cell_hints(on: boolean): void {
        this.grid.cell_hints[this.i][this.j] = on ? new CellHints() : null;
        this.grid._update_cell_hint(this.i, this.j);
    }

    add_cell_hints(flush_undo: boolean = true): boolean {
        if (this.hints() != null) return false;
        this._set_cell_hints(true);
        this.grid._push_undo_changes([new CellHintsChange(this.i, this.j, false)], flush_undo);
        return true;
    }

    rem_cell_hints(flush_undo: boolean = true): boolean {
        if (this.hints() == null) return false;
        this._set_cell_hints(false);
        this.grid._push_undo_changes([new CellHintsChange(this.i, this.j, true)], flush_undo);
        return true;
    }

    hints(): CellHints {
        return this.grid.cell_hints[this.i]?.[this.j] as CellHints;
    }

    hints_status(): E.HintStatus {
        return this.grid.cell_hint_status(this.i, this.j);
    }
}

export interface AreaCheck {
    inside(i: number, j: number): boolean;
    all_points?(): Vector2i[];
}

export class Dfs {
    grid: GridImpl;
    changes: Change[] = [];
    area_check: AreaCheck | null;

    constructor(grid: GridImpl, area_check: AreaCheck | null = null) {
        this.grid = grid;
        this.grid.last_seen += 1;
        this.area_check = area_check;
    }

    ok(i: number, j: number): boolean {
        return this.area_check == null || this.area_check.inside(i, j);
    }

    flood(i: number, j: number, corner: E.Corner): void {
        const cell = this.grid._pure_cell(i, j);
        if (cell.last_seen(corner) >= this.grid.last_seen) return;
        cell.set_last_seen(corner, this.grid.last_seen);

        const prev_cell = cell.clone();
        const keep_going = this._cell_logic(i, j, corner, cell);
        if (!cell.eq(prev_cell)) {
            this.changes.push(new CellChange(i, j, prev_cell));
        }
        if (!keep_going) return;

        const is_left = E.corner_is_left(corner);
        const is_top = E.corner_is_top(corner);

        // Left
        if (!this.grid._has_wall_left(i, j) && !(cell.type !== E.CellType.Single && !is_left) && this.ok(i, j - 1)) {
            this.flood(i, j - 1, E.diag_to_corner(this.grid._pure_cell(i, j - 1).type, E.Side.Right));
        }
        // Right
        if (!this.grid._has_wall_right(i, j) && !(cell.type !== E.CellType.Single && is_left) && this.ok(i, j + 1)) {
            this.flood(i, j + 1, E.diag_to_corner(this.grid._pure_cell(i, j + 1).type, E.Side.Left));
        }
        // Down
        if (!this.grid._has_wall_bottom(i, j) && !(cell.type !== E.CellType.Single && is_top) && this.ok(i + 1, j) && this._can_go_down(i, j)) {
            this.flood(i + 1, j, E.diag_to_corner(this.grid._pure_cell(i + 1, j).type, E.Side.Top));
        }
        // Up
        if (!this.grid._has_wall_top(i, j) && !(cell.type !== E.CellType.Single && !is_top) && this.ok(i - 1, j) && this._can_go_up(i, j)) {
            this.flood(i - 1, j, E.diag_to_corner(this.grid._pure_cell(i - 1, j).type, E.Side.Bottom));
        }
    }

    _cell_logic(i: number, j: number, corner: E.Corner, cell: PureCell): boolean { return true; }
    _can_go_up(i: number, j: number): boolean { return true; }
    _can_go_down(i: number, j: number): boolean { return true; }
}

export class AddWaterDfs extends Dfs {
    min_i: number;
    added_waters: number = 0.0;
    dry_run: boolean = false;
    water_locs: WaterPosition[] = [];

    constructor(grid: GridImpl, min_i: number, area_check: AreaCheck | null = null) {
        super(grid, area_check);
        this.min_i = min_i;
    }

    _cell_logic(i: number, j: number, corner: E.Corner, cell: PureCell): boolean {
        const c = cell._content_at(corner);
        switch (c) {
            case Content.Nothing:
            case Content.NoWater:
            case Content.Boat:
            case Content.Water:
            case Content.NoBoat:
            case Content.NoBoatWater: {
                const pos: E.Waters = cell.cell_type() === E.CellType.Single ? E.Waters.Single : (corner as unknown as E.Waters);
                if (c !== Content.Water) {
                    this.added_waters += E.waters_size(pos);
                    if (this.dry_run) {
                        this.water_locs.push(new WaterPosition(i, j, pos));
                    }
                }
                if (!this.dry_run) {
                    cell.put_water(corner);
                }
                return true;
            }
            case Content.Block:
                return false;
        }
    }

    _can_go_up(i: number, j: number): boolean { return i - 1 >= this.min_i; }
    _can_go_down(i: number, j: number): boolean { return true; }
}

export class RemoveWaterDfs extends Dfs {
    min_i: number;

    constructor(grid: GridImpl, min_i: number) {
        super(grid);
        this.min_i = min_i;
    }

    _cell_logic(i: number, j: number, corner: E.Corner, cell: PureCell): boolean {
        const content = cell._content_at(corner);
        if (i <= this.min_i) {
            if (content === Content.Water) {
                return cell.put_nothing(corner);
            } else if (content === Content.Boat) {
                cell.put_nothing(corner);
            }
            return false;
        } else {
            return content === Content.Water;
        }
    }

    _can_go_up(i: number, j: number): boolean { return true; }
    _can_go_down(i: number, j: number): boolean { return i >= this.min_i; }
}

export class RemoveNoWaterDfs extends Dfs {
    constructor(grid: GridImpl) {
        super(grid);
    }

    _cell_logic(i: number, j: number, corner: E.Corner, cell: PureCell): boolean {
        const content = cell._content_at(corner);
        if (content === Content.NoWater || content === Content.NoBoatWater) {
            cell.remove_content(corner);
            return true;
        }
        return false;
    }

    _can_go_up(i: number, j: number): boolean { return false; }
    _can_go_down(i: number, j: number): boolean { return true; }
}

export class AddNoWaterDfs extends Dfs {
    added_nowater: number = 0.0;
    dry_run: boolean = false;

    _cell_logic(i: number, j: number, corner: E.Corner, cell: PureCell): boolean {
        const c = cell._content_at(corner);
        switch (c) {
            case Content.Water:
            case Content.Nothing:
            case Content.NoWater:
            case Content.NoBoat:
            case Content.NoBoatWater:
                if (c !== Content.NoWater) {
                    if (cell.cell_type() === E.CellType.Single) {
                        this.added_nowater += 1.0;
                    } else {
                        this.added_nowater += 0.5;
                    }
                }
                if (!this.dry_run) {
                    cell.put_nowater(corner, false);
                }
                return true;
            case Content.Block:
            case Content.Boat:
                return true;
        }
    }

    _can_go_up(i: number, j: number): boolean { return true; }
    _can_go_down(i: number, j: number): boolean { return false; }
}

export class CountWaterDfs extends Dfs {
    water_count: number = 0;

    _cell_logic(i: number, j: number, corner: E.Corner, cell: PureCell): boolean {
        this.water_count += cell._content_count_from(Content.Water, corner);
        return true;
    }

    _can_go_up(i: number, j: number): boolean { return true; }
    _can_go_down(i: number, j: number): boolean { return true; }
}

export class ComponentInfo {
    total_water: number = 0;
    total_empty: number = 0;
    empties: WaterPosition[] = [];
    neighbors: WaterPosition[] = [];
}

export abstract class BaseAdjDfs {
    grid: GridImpl;
    rect: Rect2i;
    info: ComponentInfo | null = null;

    constructor(grid: GridImpl, ci: number, cj: number) {
        this.grid = grid;
        this.grid.last_seen += 1;
        this.rect = new Rect2i(ci - 1, 2 * cj - 2, 3, 6).intersection(new Rect2i(0, 0, grid.n, 2 * grid.m));
    }

    calc_component_info(): void {
        this.info = new ComponentInfo();
    }

    has_point(i: number, j2: number): boolean {
        return this.rect.has_point(new Vector2i(i, j2));
    }

    abstract _is_content_ok(c: Content): boolean;

    content(i: number, j2: number): Content {
        const c = this.grid._pure_cell(i, Math.floor(j2 / 2));
        return (j2 & 1) === 0 ? c.c_left : c.c_right;
    }

    has_ok_content(i: number, j2: number): boolean {
        return this.has_point(i, j2) && this._is_content_ok(this.content(i, j2));
    }

    add_to_vec(arr: WaterPosition[], i: number, j2: number): void {
        const type = this.grid._pure_cell(i, Math.floor(j2 / 2)).type;
        if (type === E.CellType.Single) {
            if ((j2 & 1) === 0) {
                arr.push(new WaterPosition(i, Math.floor(j2 / 2), E.Waters.Single));
            }
        } else {
            const corner = E.diag_to_corner(type, (j2 & 1) === 0 ? E.Side.Left : E.Side.Right);
            arr.push(new WaterPosition(i, Math.floor(j2 / 2), corner as unknown as E.Waters));
        }
    }

    _maybe_go(stack: Vector2i[], i: number, j2: number, first: boolean): void {
        if (this.has_ok_content(i, j2)) {
            const c = this.grid._pure_cell(i, Math.floor(j2 / 2));
            if ((j2 & 1) === 0) {
                if (c.last_seen_left < this.grid.last_seen) {
                    c.last_seen_left = this.grid.last_seen;
                    stack.push(new Vector2i(i, j2));
                }
            } else if (c.last_seen_right < this.grid.last_seen) {
                c.last_seen_right = this.grid.last_seen;
                stack.push(new Vector2i(i, j2));
            }
        } else if (!first && this.info != null && this.has_point(i, j2)) {
            this.add_to_vec(this.info.neighbors, i, j2);
        }
    }

    add_to_comp(i: number, j2: number): void {
        if (!this.info) return;
        const c = this.content(i, j2);
        if (c === Content.Water) {
            this.info.total_water += 0.5;
        } else if (c === Content.Nothing || c === Content.NoBoat) {
            this.info.total_empty += 0.5;
            this.add_to_vec(this.info.empties, i, j2);
        }
    }

    static all_adj(ngrid: GridImpl, v: Vector2i, count_full_cell: boolean = false): Vector2i[] {
        const arr: Vector2i[] = [];
        let dright = 0;
        let dleft = 0;
        const is_full_cell = count_full_cell && Ij2.waters(ngrid, v) === E.Waters.Single;
        if (count_full_cell && is_full_cell) {
            dright = 1;
        }
        if (count_full_cell && v.y > 0 && (v.y & 1) === 0 && ngrid.get_cell(v.x, Math.floor((v.y - 1) / 2)).cell_type() === E.CellType.Single) {
            dleft = 1;
        }
        arr.push(new Vector2i(v.x, v.y + 1 + dright));
        arr.push(new Vector2i(v.x, v.y - 1 - dleft));
        const nj2 = v.y & ~1;
        const go_up = (ngrid._pure_cell(v.x, Math.floor(v.y / 2)).type === E.CellType.IncDiag) === ((v.y & 1) === 0);
        if (go_up || (count_full_cell && is_full_cell)) {
            if (v.x > 0) {
                arr.push(new Vector2i(v.x - 1, nj2 | (ngrid._pure_cell(v.x - 1, Math.floor(v.y / 2)).type === E.CellType.IncDiag ? 1 : 0)));
            }
        }
        if (!go_up || (count_full_cell && is_full_cell)) {
            if (v.x < ngrid.n - 1) {
                arr.push(new Vector2i(v.x + 1, nj2 | (ngrid._pure_cell(v.x + 1, Math.floor(v.y / 2)).type === E.CellType.DecDiag ? 1 : 0)));
            }
        }
        return arr;
    }

    flood(i: number, j2: number): boolean {
        const stack: Vector2i[] = [];
        this._maybe_go(stack, i, j2, true);
        if (stack.length === 0) return false;
        if (this.info != null) {
            this.info = new ComponentInfo();
        }
        while (stack.length > 0) {
            const v = stack.pop()!;
            this.add_to_comp(v.x, v.y);
            for (const adj of BaseAdjDfs.all_adj(this.grid, v)) {
                this._maybe_go(stack, adj.x, adj.y, false);
            }
        }
        return true;
    }
}

export class WaterAdjDfs extends BaseAdjDfs {
    _is_content_ok(c: Content): boolean {
        return c === Content.Water;
    }
}

export class GridImpl extends GridModel {
    n: number = 0;
    m: number = 0;
    pure_cells: PureCell[][] = [];
    cell_hints: (CellHints | null)[][] = [];
    _row_hints: LineHint[] = [];
    _col_hints: LineHint[] = [];
    _grid_hints: GridHints = new GridHints();
    wall_bottom: boolean[][] = [];
    wall_right: boolean[][] = [];
    last_seen: number = 0;
    undo_stack: Changes[] = [];
    redo_stack: Changes[] = [];

    solution_c_left: Content[][] = [];
    solution_c_right: Content[][] = [];
    auto_update_hints_: boolean = false;
    _force_editor_mode: boolean = false;

    static empty_editor(rows: number, cols: number): GridImpl {
        const g = new GridImpl(rows, cols);
        g.set_auto_update_hints(true);
        return g;
    }

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

        if (data.solution_c_left && data.solution_c_left.length > 0) {
            grid.solution_c_left = data.solution_c_left.map(r => [...r]);
            grid.solution_c_right = (data.solution_c_right || []).map(r => [...r]);
        }

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
            grid_hints: this._grid_hints,
            solution_c_left: this.solution_c_left.map(r => [...r]),
            solution_c_right: this.solution_c_right.map(r => [...r])
        };
    }

    static import_data(data: any, load_mode: LoadMode = LoadMode.Testing): GridImpl {
        return new GridExporter().load_data(new GridImpl(0, 0), data, load_mode, PureCell);
    }

    static from_str(s: string, load_mode: LoadMode = LoadMode.Solution): GridImpl {
        s = s.replace(/\r/g, '').replace(/\t/g, '').trim();
        let my_s = s;
        while (my_s.startsWith('+')) {
            const idx = my_s.indexOf('\n');
            my_s = idx !== -1 ? my_s.substring(idx + 1).trim() : '';
        }
        const newlineCount = (my_s.match(/\n/g) || []).length;
        let rows_ = Math.floor((newlineCount + 1) / 2);
        const firstNewline = my_s.indexOf('\n');
        let cols_ = Math.floor((firstNewline !== -1 ? firstNewline : my_s.length) / 2);
        if (my_s.startsWith('B') && my_s.indexOf('h') !== -1) {
            rows_ -= 1;
            cols_ -= 1;
        }
        const g = new GridImpl(rows_, cols_);
        g.load_from_str(s, load_mode);
        return g;
    }

    constructor(n: number, m: number) {
        super();
        this.setup(n, m);
    }

    _empty_line_hint(): LineHint {
        const hint = new LineHint();
        hint.water_count = -1.0;
        hint.water_count_type = E.HintType.Hidden;
        hint.boat_count = -1;
        hint.boat_count_type = E.HintType.Hidden;
        return hint;
    }

    reset_cell_hints(): void {
        this.cell_hints = [];
        for (let i = 0; i < this.n; i++) {
            const row: (CellHints | null)[] = new Array(this.m).fill(null);
            this.cell_hints.push(row);
        }
    }

    setup(n: number, m: number): void {
        this.n = n;
        this.m = m;
        this.pure_cells = [];
        this.reset_cell_hints();
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
            this._row_hints.push(this._empty_line_hint());
        }
        for (let j = 0; j < m; j++) {
            this._col_hints.push(this._empty_line_hint());
        }
        this._grid_hints = new GridHints();
        this._grid_hints.total_water = -1.0;
        this._grid_hints.total_boats = 0;
        this._grid_hints.expected_aquariums = {};
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
            case E.Side.Top: return this._has_wall_top(i, j);
            case E.Side.Bottom: return this._has_wall_bottom(i, j);
            case E.Side.Left: return this._has_wall_left(i, j);
            case E.Side.Right: return this._has_wall_right(i, j);
        }
    }

    _has_wall_bottom(i: number, j: number): boolean {
        return i === this.n - 1 || this.wall_bottom[i][j] ||
            this.pure_cells[i][j]._content_bottom() === Content.Block ||
            (i + 1 < this.n && this.pure_cells[i + 1][j]._content_top() === Content.Block);
    }

    _has_wall_top(i: number, j: number): boolean {
        return i === 0 || this._has_wall_bottom(i - 1, j);
    }

    _has_wall_right(i: number, j: number): boolean {
        return j === this.m - 1 || this.wall_right[i][j] ||
            this.pure_cells[i][j].c_right === Content.Block ||
            (j + 1 < this.m && this.pure_cells[i][j + 1].c_left === Content.Block);
    }

    _has_wall_left(i: number, j: number): boolean {
        return j === 0 || this._has_wall_right(i, j - 1);
    }

    _change_wall(i: number, j: number, side: E.Side, new_val: boolean): void {
        if (side === E.Side.Left) return this._change_wall(i, j - 1, E.Side.Right, new_val);
        if (side === E.Side.Top) return this._change_wall(i - 1, j, E.Side.Bottom, new_val);
        if (side === E.Side.Right && j >= 0 && j < this.m - 1) {
            this.wall_right[i][j] = new_val;
        }
        if (side === E.Side.Bottom && i >= 0 && i < this.n - 1) {
            this.wall_bottom[i][j] = new_val;
        }
    }

    _idx_to_cell_wall(i1: number, j1: number, i2: number, j2: number): Vector3i[] {
        if (Math.min(i1, i2) < 0 || Math.min(j1, j2) < 0 || Math.max(i1, i2) > this.n || Math.max(j1, j2) > this.m) {
            return [];
        }
        const ans: Vector3i[] = [];
        if (i1 === i2) {
            for (let j = Math.min(j1, j2); j < Math.max(j1, j2); j++) {
                if (i1 === 0) {
                    ans.push(new Vector3i(i1, j, E.Walls.Top));
                } else {
                    ans.push(new Vector3i(i1 - 1, j, E.Walls.Bottom));
                }
            }
        } else if (j1 === j2) {
            for (let i = Math.min(i1, i2); i < Math.max(i1, i2); i++) {
                if (j1 === 0) {
                    ans.push(new Vector3i(i, j1, E.Walls.Left));
                } else {
                    ans.push(new Vector3i(i, j1 - 1, E.Walls.Right));
                }
            }
        } else if ((i2 - i1) === (j1 - j2)) {
            let j = Math.max(j1, j2);
            for (let i = Math.min(i1, i2); i < Math.max(i1, i2); i++) {
                j -= 1;
                ans.push(new Vector3i(i, j, E.Walls.IncDiag));
            }
        } else if ((i2 - i1) === (j2 - j1)) {
            let j = Math.min(j1, j2);
            for (let i = Math.min(i1, i2); i < Math.max(i1, i2); i++) {
                ans.push(new Vector3i(i, j, E.Walls.DecDiag));
                j += 1;
            }
        }
        return ans;
    }

    put_wall_from_idx(i1: number, j1: number, i2: number, j2: number, flush_undo: boolean = true): boolean {
        if (flush_undo) this.push_empty_undo();
        const walls = this._idx_to_cell_wall(i1, j1, i2, j2);
        if (walls.length === 0) return false;
        for (const cw of walls) {
            (this.get_cell(cw.x, cw.y) as CellWithLoc).put_wall(cw.z as unknown as E.Walls, false);
        }
        return true;
    }

    remove_wall_from_idx(i1: number, j1: number, i2: number, j2: number, flush_undo: boolean = true): boolean {
        if (flush_undo) this.push_empty_undo();
        const walls = this._idx_to_cell_wall(i1, j1, i2, j2);
        if (walls.length === 0) return false;
        for (const cw of walls) {
            (this.get_cell(cw.x, cw.y) as CellWithLoc).remove_wall(cw.z as unknown as E.Walls, false);
        }
        return true;
    }

    _flood_water(i: number, j: number, corner: E.Corner, add: boolean): Dfs {
        if (add) {
            const dfs = new AddWaterDfs(this, i);
            dfs.flood(i, j, corner);
            return dfs;
        } else {
            const dfs = new RemoveWaterDfs(this, i);
            dfs.flood(i, j, corner);
            return dfs;
        }
    }

    row_hints(): LineHint[] { return this._row_hints; }
    col_hints(): LineHint[] { return this._col_hints; }

    _do_add_row(row: PureCell[], hints: (CellHints | null)[], new_wall_bottom: boolean[], new_wall_right: boolean[], new_line_hint: LineHint): AddRowChange {
        if (row.length === 0) {
            for (let j = 0; j < this.m; j++) row.push(PureCell.empty());
        }
        if (hints.length === 0) {
            for (let j = 0; j < this.m; j++) hints.push(null);
        }
        if (new_wall_bottom.length === 0) {
            new_wall_bottom = new Array(this.m).fill(false);
        }
        if (new_wall_right.length === 0) {
            new_wall_right = new Array(Math.max(0, this.m - 1)).fill(false);
        }
        this.n += 1;
        this.pure_cells.push(row);
        this.cell_hints.push(hints);
        if (this.n > 1) {
            this.wall_bottom.push(new_wall_bottom);
        }
        this.wall_right.push(new_wall_right);
        this._row_hints.push(new_line_hint);
        this.maybe_update_hints();
        this.validate();
        return new AddRowChange();
    }

    _do_rem_row(): RemRowChange {
        this.n -= 1;
        const prev_row = this.pure_cells.pop()!;
        const prev_hints = this.cell_hints.pop()!;
        const prev_wall_bottom = this.wall_bottom.length > 0 ? this.wall_bottom.pop()! : [];
        const prev_wall_right = this.wall_right.pop()!;
        const hint = this._row_hints.pop()!;
        this.fix_invalid_boats(false);
        this.maybe_update_hints();
        this.validate();
        return new RemRowChange(prev_row, prev_hints, prev_wall_bottom, prev_wall_right, hint);
    }

    add_row(flush_undo: boolean = true): void {
        const change = this._do_add_row([], [], [], [], this._empty_line_hint());
        this._push_undo_changes([change], flush_undo);
        this.flood_all(false);
        this.maybe_update_hints();
        this.validate();
    }

    rem_row(flush_undo: boolean = true): void {
        if (this.n <= 1) return;
        if (flush_undo) this.push_empty_undo();
        const change = this._do_rem_row();
        this._push_undo_changes([change], false);
    }

    _do_add_col(col: PureCell[], hints: (CellHints | null)[], new_wall_bottom: boolean[], new_wall_right: boolean[], new_line_hint: LineHint): AddColChange {
        if (col.length === 0) {
            for (let i = 0; i < this.n; i++) col.push(PureCell.empty());
        }
        if (hints.length === 0) {
            for (let i = 0; i < this.n; i++) hints.push(null);
        }
        if (new_wall_bottom.length === 0) {
            new_wall_bottom = new Array(Math.max(0, this.n - 1)).fill(false);
        }
        if (new_wall_right.length === 0) {
            new_wall_right = new Array(this.n).fill(false);
        }
        this.m += 1;
        for (let i = 0; i < this.n; i++) {
            this.pure_cells[i].push(col[i]);
            this.cell_hints[i].push(hints[i]);
            if (i !== this.n - 1) {
                this.wall_bottom[i].push(new_wall_bottom[i]);
            }
            if (this.m > 1) {
                this.wall_right[i].push(new_wall_right[i]);
            }
        }
        this._col_hints.push(new_line_hint);
        this.maybe_update_hints();
        this.validate();
        return new AddColChange();
    }

    _do_rem_col(): RemColChange {
        this.m -= 1;
        const prev_col: PureCell[] = [];
        const prev_hints: (CellHints | null)[] = [];
        const prev_wall_bottom: boolean[] = [];
        const prev_wall_right: boolean[] = [];
        for (let i = 0; i < this.n; i++) {
            prev_col.push(this.pure_cells[i].pop()!.clone());
            prev_hints.push(this.cell_hints[i].pop()!);
            if (i !== this.n - 1) {
                prev_wall_bottom.push(this.wall_bottom[i].pop()!);
            }
            if (this.wall_right[i].length > 0) {
                prev_wall_right.push(this.wall_right[i].pop()!);
            }
        }
        const hint = this._col_hints.pop()!;
        this.maybe_update_hints();
        this.validate();
        return new RemColChange(prev_col, prev_hints, prev_wall_bottom, prev_wall_right, hint);
    }

    add_col(flush_undo: boolean = true): void {
        const change = this._do_add_col([], [], [], [], this._empty_line_hint());
        this._push_undo_changes([change], flush_undo);
        this.flood_all(false);
        this.maybe_update_hints();
        this.validate();
    }

    rem_col(flush_undo: boolean = true): void {
        if (this.m <= 1) return;
        const change = this._do_rem_col();
        this._push_undo_changes([change], flush_undo);
    }

    get_expected_boats(): number { return this._grid_hints.total_boats; }
    get_expected_waters(): number { return this._grid_hints.total_water; }

    count_boats(): number {
        let c = 0;
        for (let i = 0; i < this.n; i++) c += this.count_boat_row(i);
        return c;
    }

    count_waters(): number {
        let c = 0.0;
        for (let i = 0; i < this.n; i++) c += this.count_water_row(i);
        return c;
    }

    count_nowaters(): number {
        let c = 0.0;
        for (let i = 0; i < this.n; i++) {
            for (let j = 0; j < this.m; j++) c += this._pure_cell(i, j).nowater_count();
        }
        return c;
    }

    count_blocks(): number {
        let c = 0.0;
        for (let i = 0; i < this.n; i++) {
            for (let j = 0; j < this.m; j++) c += this._pure_cell(i, j).block_count();
        }
        return c;
    }

    count_water_row(i: number): number {
        let c = 0.0;
        for (let j = 0; j < this.m; j++) c += this._pure_cell(i, j).water_count();
        return c;
    }

    count_water_col(j: number): number {
        let c = 0.0;
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

    _hint_statusi(count: number, hint: number): E.HintStatus {
        return this._hint_statusf(count, hint);
    }

    all_boats_hint_status(): E.HintStatus { return this._hint_statusi(this.count_boats(), this.get_expected_boats()); }
    all_waters_hint_status(): E.HintStatus { return this._hint_statusf(this.count_waters(), this.get_expected_waters()); }

    merge_status(s1: E.HintStatus, s2: E.HintStatus): E.HintStatus {
        if (s1 === E.HintStatus.Wrong || s2 === E.HintStatus.Wrong) return E.HintStatus.Wrong;
        if (s1 === E.HintStatus.Normal || s2 === E.HintStatus.Normal) return E.HintStatus.Normal;
        return E.HintStatus.Satisfied;
    }

    _is_together(a: boolean[]): E.HintType {
        let i = 0;
        while (i < a.length && !a[i]) i++;
        if (i === a.length) return E.HintType.Zero;
        while (i < a.length && a[i]) i++;
        while (i < a.length && !a[i]) i++;
        return i === a.length ? E.HintType.Together : E.HintType.Separated;
    }

    _hint_type_ok(hint: E.HintType, a: boolean[]): boolean {
        if (hint === E.HintType.Hidden) return true;
        return this._is_together(a) === hint;
    }

    _status_and_then(status: E.HintStatus, together_match: boolean, is_question_mark: boolean): E.HintStatus {
        if (status === E.HintStatus.Satisfied && !together_match) {
            return is_question_mark ? E.HintStatus.Normal : E.HintStatus.Wrong;
        }
        return status;
    }

    _row_bools(i: number, content: Content): boolean[] {
        const a: boolean[] = [];
        for (let j = 0; j < this.m; j++) {
            a.push(this._pure_cell(i, j)._content_left() === content);
            a.push(this._pure_cell(i, j)._content_right() === content);
        }
        return a;
    }

    _col_bools(j: number, content: Content): boolean[] {
        const a: boolean[] = [];
        for (let i = 0; i < this.n; i++) {
            a.push(this._pure_cell(i, j)._content_top() === content);
            a.push(this._pure_cell(i, j)._content_bottom() === content);
        }
        return a;
    }

    get_row_hint_status(i: number, hint_content: E.HintContent): E.HintStatus {
        const hint = this._row_hints[i];
        if (hint_content === E.HintContent.Boat) {
            const count = hint.boat_count;
            const status = this._hint_statusi(this.count_boat_row(i), count);
            const type = this._hint_type_ok(hint.boat_count_type, this._row_bools(i, Content.Boat));
            return this._status_and_then(status, type, count === -1);
        } else {
            const count = hint.water_count;
            const status = this._hint_statusf(this.count_water_row(i), count);
            const type = this._hint_type_ok(hint.water_count_type, this._row_bools(i, Content.Water));
            return this._status_and_then(status, type, count === -1.0);
        }
    }

    get_col_hint_status(j: number, hint_content: E.HintContent): E.HintStatus {
        const hint = this._col_hints[j];
        if (hint_content === E.HintContent.Boat) {
            const count = hint.boat_count;
            const status = this._hint_statusi(this.count_boat_col(j), count);
            const type = this._hint_type_ok(hint.boat_count_type, this._col_bools(j, Content.Boat));
            return this._status_and_then(status, type, count === -1);
        } else {
            const count = hint.water_count;
            const status = this._hint_statusf(this.count_water_col(j), count);
            const type = this._hint_type_ok(hint.water_count_type, this._col_bools(j, Content.Water));
            return this._status_and_then(status, type, count === -1.0);
        }
    }

    cell_hint_status(i: number, j: number): E.HintStatus {
        const c = this.cell_hints[i]?.[j];
        if (!c) return E.HintStatus.Satisfied;
        const water = this.count_water_adj(i, j);
        const status = this._hint_statusf(water, c.adj_water_count);
        const ok_type = c.adj_water_count_type === E.HintType.Hidden || (this.together_waters_adj(water, i, j) === c.adj_water_count_type);
        return this._status_and_then(status, ok_type, c.adj_water_count === -1);
    }

    all_hints_status(): E.HintStatus {
        let s = E.HintStatus.Satisfied;
        s = this.merge_status(s, this.all_boats_hint_status());
        if (s === E.HintStatus.Wrong) return s;
        s = this.merge_status(s, this.all_waters_hint_status());
        if (s === E.HintStatus.Wrong) return s;
        s = this.merge_status(s, this.aquarium_hints_status());
        if (s === E.HintStatus.Wrong) return s;
        for (let i = 0; i < this.n; i++) {
            s = this.merge_status(s, this.get_row_hint_status(i, E.HintContent.Water));
            if (s === E.HintStatus.Wrong) return s;
            s = this.merge_status(s, this.get_row_hint_status(i, E.HintContent.Boat));
            if (s === E.HintStatus.Wrong) return s;
        }
        for (let j = 0; j < this.m; j++) {
            s = this.merge_status(s, this.get_col_hint_status(j, E.HintContent.Water));
            if (s === E.HintStatus.Wrong) return s;
            s = this.merge_status(s, this.get_col_hint_status(j, E.HintContent.Boat));
            if (s === E.HintStatus.Wrong) return s;
        }
        for (let i = 0; i < this.n; i++) {
            for (let j = 0; j < this.m; j++) {
                s = this.merge_status(s, this.cell_hint_status(i, j));
                if (s === E.HintStatus.Wrong) return s;
            }
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

    are_hints_satisfied(check_complete: boolean = false): boolean {
        if (check_complete && !this.check_complete()) return false;
        return this.all_hints_status() === E.HintStatus.Satisfied;
    }

    is_any_hint_broken(): boolean {
        return this.all_hints_status() === E.HintStatus.Wrong;
    }

    _count_content_adj(i: number, j: number, c: Content): number {
        let count = 0.0;
        for (const di of [-1, 0, 1]) {
            for (const dj of [-1, 0, 1]) {
                if (i + di >= 0 && i + di < this.n && j + dj >= 0 && j + dj < this.m) {
                    count += this._pure_cell(i + di, j + dj)._content_count(c);
                }
            }
        }
        return count;
    }

    count_water_adj(i: number, j: number): number {
        return this._count_content_adj(i, j, Content.Water);
    }

    count_nothing_adj(i: number, j: number): number {
        return this._count_content_adj(i, j, Content.Nothing) + this._count_content_adj(i, j, Content.NoBoat);
    }

    together_waters_adj(water: number, ci: number, cj: number): E.HintType {
        if (water === 0) return E.HintType.Zero;
        const dfs = new WaterAdjDfs(this, ci, cj);
        let any = false;
        for (let i = ci - 1; i <= ci + 1; i++) {
            for (let j2 = 2 * cj - 2; j2 <= 2 * cj + 3; j2++) {
                if (dfs.flood(i, j2)) {
                    if (any) return E.HintType.Separated;
                    any = true;
                }
            }
        }
        return E.HintType.Together;
    }

    _update_cell_hint(i: number, j: number): void {
        const c = this.cell_hints[i]?.[j];
        if (!c) return;
        c.adj_water_count = this.count_water_adj(i, j);
        c.adj_water_count_type = this.together_waters_adj(c.adj_water_count, i, j);
    }

    maybe_update_hints(): void {
        if (!this.editor_mode() || !this.auto_update_hints()) return;
        for (let i = 0; i < this.n; i++) {
            for (let j = 0; j < this.m; j++) {
                this._update_cell_hint(i, j);
            }
        }
    }

    grid_hints(): GridHints { return this._grid_hints; }

    all_aquarium_counts(): Record<number, number> {
        const dfs = new CountWaterDfs(this);
        const counts: Record<number, number> = {};
        for (let i = 0; i < this.n; i++) {
            for (let j = 0; j < this.m; j++) {
                for (const corner of [E.Corner.TopLeft, E.Corner.TopRight, E.Corner.BottomRight, E.Corner.BottomLeft]) {
                    const c = this._pure_cell(i, j);
                    if (c._valid_corner(corner) && c.last_seen(corner) < this.last_seen && !c.block_at(corner)) {
                        dfs.water_count = 0;
                        dfs.flood(i, j, corner);
                        counts[dfs.water_count] = (counts[dfs.water_count] || 0) + 1;
                    }
                }
            }
        }
        return counts;
    }

    aquarium_hints_status(): E.HintStatus {
        const aqs = this.all_aquarium_counts();
        for (const hint_size in this._grid_hints.expected_aquariums) {
            const size = parseFloat(hint_size);
            const hint_count = this._grid_hints.expected_aquariums[size];
            if (hint_count !== -1 && hint_count !== (aqs[size] || 0)) {
                return E.HintStatus.Normal;
            }
        }
        return E.HintStatus.Satisfied;
    }

    _validate(chr: string, possible: string): string {
        if (!possible.includes(chr)) {
            throw new Error(`'${chr}' is not one of '${possible}'`);
        }
        return chr;
    }

    _str_content(chr: string): Content {
        switch (chr) {
            case '.': return Content.Nothing;
            case 'w': return Content.Water;
            case 'x': return Content.NoWater;
            case 'y': return Content.NoBoat;
            case 'z': return Content.NoBoatWater;
            case '#': return Content.Block;
            case 'b': return Content.Boat;
        }
        throw new Error(`Unknown content char '${chr}'`);
    }

    _content_str(c: Content): string {
        switch (c) {
            case Content.Nothing: return '.';
            case Content.Water: return 'w';
            case Content.NoWater: return 'x';
            case Content.NoBoat: return 'y';
            case Content.NoBoatWater: return 'z';
            case Content.Block: return '#';
            case Content.Boat: return 'b';
        }
    }

    _validate_hint(c1: string, c2: string): number {
        this._validate(c1, ".0123456789");
        this._validate(c2, ".0123456789}-");
        if (c1 !== '.') {
            if (/^\d+$/.test(c2)) {
                return parseInt(c1 + c2, 10);
            } else {
                return parseInt(c1, 10);
            }
        } else {
            return -1;
        }
    }

    _validate_hint_float(c1: string, c2: string): number {
        const h = this._validate_hint(c1, c2);
        return h === -1 ? -1.0 : h / 2.0;
    }

    _validate_hint_type(c2: string): E.HintType {
        if (c2 === '}') return E.HintType.Together;
        if (c2 === '-') return E.HintType.Separated;
        return E.HintType.Hidden;
    }

    _parse_extra_data(line: string): void {
        const kv = line.split("=");
        switch (kv[0]) {
            case "+waters":
                this._grid_hints.total_water = parseFloat(kv[1]);
                break;
            case "+boats":
                this._grid_hints.total_boats = parseInt(kv[1], 10);
                break;
            case "+aqua": {
                const sv = kv[1].split(":");
                this._grid_hints.expected_aquariums[parseFloat(sv[0])] = parseInt(sv[1], 10);
                break;
            }
            case "+cellhint": {
                const sv = kv[1].split(":");
                const c = new CellHints();
                c.adj_water_count_type = E.HintType.Hidden;
                if (sv[2].startsWith("{")) c.adj_water_count_type = E.HintType.Together;
                else if (sv[2].startsWith("-")) c.adj_water_count_type = E.HintType.Separated;
                if (sv[2].includes("?")) {
                    c.adj_water_count = -1;
                } else {
                    const cleanNum = sv[2].replace(/^[\{\-]/, '').replace(/[\}\-]$/, '');
                    c.adj_water_count = parseFloat(cleanNum);
                }
                const ci = parseInt(sv[0], 10);
                const cj = parseInt(sv[1], 10);
                this.cell_hints[ci][cj] = c;
                break;
            }
        }
    }

    load_from_str(s: string, load_mode: LoadMode = LoadMode.Solution): void {
        const content_only = (load_mode === LoadMode.ContentOnly);
        const rawLines = s.replace(/\r/g, '').split('\n').map(l => l.trimEnd()).filter(l => l.trim().length > 0);
        const lines: string[] = [];
        for (const line of rawLines) {
            lines.push(line.trim());
        }
        while (lines.length > 0 && lines[0].startsWith('+')) {
            if (!content_only) {
                this._parse_extra_data(lines[0]);
            }
            lines.shift();
        }
        const hb = lines[0]?.[0] === 'B' ? 1 : 0;
        const hh = lines[hb]?.[hb] === 'h' ? 1 : 0;
        if (hb === 1 && !content_only) {
            for (let i = 0; i < this.n; i++) {
                this._row_hints[i].boat_count = this._validate_hint(lines[2 * i + 1 + hh][0], lines[2 * i + 2 + hh][0]);
                this._row_hints[i].boat_count_type = this._validate_hint_type(lines[2 * i + 2 + hh][0]);
            }
            for (let j = 0; j < this.m; j++) {
                this._col_hints[j].boat_count = this._validate_hint(lines[0][2 * j + 1 + hh], lines[0][2 * j + 2 + hh]);
                this._col_hints[j].boat_count_type = this._validate_hint_type(lines[0][2 * j + 2 + hh]);
            }
        }
        if (hh === 1 && !content_only) {
            for (let i = 0; i < this.n; i++) {
                this._row_hints[i].water_count = this._validate_hint_float(lines[2 * i + 1 + hb][hb], lines[2 * i + 2 + hb][hb]);
                this._row_hints[i].water_count_type = this._validate_hint_type(lines[2 * i + 2 + hb][hb]);
            }
            for (let j = 0; j < this.m; j++) {
                this._col_hints[j].water_count = this._validate_hint_float(lines[hb][2 * j + 1 + hb], lines[hb][2 * j + 2 + hb]);
                this._col_hints[j].water_count_type = this._validate_hint_type(lines[hb][2 * j + 2 + hb]);
            }
        }
        const h = hb + hh;
        for (let i = 0; i < this.n; i++) {
            for (let j = 0; j < this.m; j++) {
                const c1 = this._validate(lines[2 * i + h][2 * j + h], '.wxyzb#');
                const c2 = this._validate(lines[2 * i + h][2 * j + 1 + h], '.wxyzb#');
                const c3 = this._validate(lines[2 * i + 1 + h][2 * j + h], '.|_L');
                const c4 = this._validate(lines[2 * i + 1 + h][2 * j + 1 + h], '.╲/');
                const cell = this._pure_cell(i, j);
                if (!content_only || cell.c_left !== Content.Block) {
                    cell.c_left = this._str_content(c1);
                }
                if (!content_only || cell.c_right !== Content.Block) {
                    cell.c_right = this._str_content(c2);
                }
                if (!content_only) {
                    if (c4 === '╲') {
                        cell.type = E.CellType.DecDiag;
                    } else if (c4 === '/') {
                        cell.type = E.CellType.IncDiag;
                    } else {
                        cell.type = E.CellType.Single;
                    }
                    if (i < this.n - 1) {
                        this.wall_bottom[i][j] = (c3 === '_' || c3 === 'L');
                    }
                    if (j > 0) {
                        this.wall_right[i][j - 1] = (c3 === '|' || c3 === 'L');
                    }
                }
            }
        }
        this.flood_all();
        this.validate();
        this._finish_loading(load_mode);
    }

    _finish_loading(load_mode: LoadMode): void {
        this.undo_stack = [];
        this.redo_stack = [];
        if (load_mode === LoadMode.Solution || load_mode === LoadMode.SolutionNoClear) {
            const hasSolutionContent = this.pure_cells.some(row =>
                row.some(c => c.c_left === Content.Water || c.c_left === Content.Boat || c.c_right === Content.Water || c.c_right === Content.Boat)
            );
            if (hasSolutionContent) {
                this.solution_c_left = [];
                this.solution_c_right = [];
                for (let i = 0; i < this.n; i++) {
                    this.solution_c_left.push(this.pure_cells[i].map(c => c.c_left));
                    this.solution_c_right.push(this.pure_cells[i].map(c => c.c_right));
                }
                if (load_mode !== LoadMode.SolutionNoClear) {
                    this.clear_content();
                }
            } else {
                this.solution_c_left = [];
                this.solution_c_right = [];
            }
        }
        this.auto_update_hints_ = load_mode === LoadMode.Editor;
        this.maybe_update_hints();
        this.validate();
    }

    _col_hint(h: number, type: E.HintType): string {
        if (type === E.HintType.Separated) {
            return `${h >= 0 ? h : "."}-`;
        } else if (type === E.HintType.Together) {
            return `${h >= 0 ? h : "."}}`;
        } else if (h < 0) {
            return "..";
        } else if (h < 10) {
            return `${h}.`;
        } else {
            return `${h}`;
        }
    }

    _row_hint1(h: number): string {
        if (h < 0) return ".";
        if (h >= 10) return `${Math.floor(h / 10)}`;
        return `${h}`;
    }

    _row_hint2(h: number, type: E.HintType): string {
        if (type === E.HintType.Separated) return "-";
        if (type === E.HintType.Together) return "}";
        if (h >= 10) return `${h % 10}`;
        return ".";
    }

    to_str(): string {
        let res = "";
        if (this._grid_hints.total_water !== -1) {
            res += `+waters=${this._grid_hints.total_water.toFixed(1)}\n`;
        }
        if (this._grid_hints.total_boats !== 0) {
            res += `+boats=${this._grid_hints.total_boats}\n`;
        }
        for (const sz in this._grid_hints.expected_aquariums) {
            res += `+aqua=${parseFloat(sz).toFixed(1)}:${this._grid_hints.expected_aquariums[parseFloat(sz)]}\n`;
        }
        for (let i = 0; i < this.n; i++) {
            for (let j = 0; j < this.m; j++) {
                const h = (this.get_cell(i, j) as CellWithLoc).hints();
                if (h != null) {
                    let op = "";
                    let cl = "";
                    if (h.adj_water_count_type === E.HintType.Together) {
                        op = "{"; cl = "}";
                    } else if (h.adj_water_count_type === E.HintType.Separated) {
                        op = "-"; cl = "-";
                    }
                    const numStr = h.adj_water_count !== -1 ? h.adj_water_count.toFixed(1) : "?";
                    res += `+cellhint=${i}:${j}:${op}${numStr}${cl}\n`;
                }
            }
        }
        const boat_hints = this._row_hints.some(h => h.boat_count !== -1 || h.boat_count_type !== E.HintType.Hidden) ||
            this._col_hints.some(h => h.boat_count !== -1 || h.boat_count_type !== E.HintType.Hidden);
        const hints = this._row_hints.some(h => h.water_count !== -1.0 || h.water_count_type !== E.HintType.Hidden) ||
            this._col_hints.some(h => h.water_count !== -1.0 || h.water_count_type !== E.HintType.Hidden);

        if (boat_hints) {
            res += 'B';
            if (hints) res += '.';
            for (let j = 0; j < this.m; j++) {
                res += this._col_hint(this._col_hints[j].boat_count, this._col_hints[j].boat_count_type);
            }
            res += '\n';
        }
        if (hints) {
            if (boat_hints) res += '.';
            res += 'h';
            for (let j = 0; j < this.m; j++) {
                res += this._col_hint(Math.round(this._col_hints[j].water_count * 2), this._col_hints[j].water_count_type);
            }
            res += '\n';
        }
        for (let i = 0; i < this.n; i++) {
            if (boat_hints) res += this._row_hint1(this._row_hints[i].boat_count);
            if (hints) res += this._row_hint1(Math.round(this._row_hints[i].water_count * 2));
            for (let j = 0; j < this.m; j++) {
                const cell = this._pure_cell(i, j);
                res += this._content_str(cell.c_left);
                res += this._content_str(cell.c_right);
            }
            res += '\n';

            if (boat_hints) res += this._row_hint2(this._row_hints[i].boat_count, this._row_hints[i].boat_count_type);
            if (hints) res += this._row_hint2(Math.round(this._row_hints[i].water_count * 2), this._row_hints[i].water_count_type);
            for (let j = 0; j < this.m; j++) {
                const left = this._has_wall_left(i, j);
                const down = this._has_wall_bottom(i, j);
                if (left) {
                    res += down ? "L" : "|";
                } else {
                    res += down ? "_" : ".";
                }
                const cell = this._pure_cell(i, j);
                if (cell.type === E.CellType.Single) {
                    res += ".";
                } else {
                    res += cell.type === E.CellType.DecDiag ? "╲" : "/";
                }
            }
            res += '\n';
        }
        return res;
    }

    _undo_impl(undos: Changes[], redos: Changes[], skip_empty: boolean): boolean {
        while (skip_empty && undos.length > 0 && undos[undos.length - 1].changes.length === 0) {
            undos.pop();
        }
        if (undos.length === 0) return false;
        const changes = undos.pop()!.changes;
        changes.reverse();
        for (let i = 0; i < changes.length; i++) {
            changes[i] = changes[i].undo(this);
        }
        redos.push(new Changes(changes));
        this.maybe_update_hints();
        return true;
    }

    undo(skip_empty: boolean = true): boolean {
        return this._undo_impl(this.undo_stack, this.redo_stack, skip_empty);
    }

    redo(skip_empty: boolean = true): boolean {
        return this._undo_impl(this.redo_stack, this.undo_stack, skip_empty);
    }

    push_empty_undo(): void {
        this._push_undo_changes([], true);
    }

    _push_undo_changes(changes: Change[], flush_first: boolean): void {
        this.redo_stack = [];
        while (flush_first && this.undo_stack.length > 0 && this.undo_stack[this.undo_stack.length - 1].changes.length === 0) {
            this.undo_stack.pop();
        }
        if (flush_first || this.undo_stack.length === 0) {
            this.undo_stack.push(new Changes([...changes]));
        } else {
            this.undo_stack[this.undo_stack.length - 1].changes.push(...changes);
        }
    }

    flood_all(flush_undo: boolean = true): boolean {
        const dfs = new AddWaterDfs(this, 0);
        for (let i = 0; i < this.n; i++) {
            for (let j = 0; j < this.m; j++) {
                const c = this._pure_cell(i, j);
                for (const corner of [E.Corner.TopLeft, E.Corner.TopRight, E.Corner.BottomRight, E.Corner.BottomLeft]) {
                    if (c._valid_corner(corner) && c.last_seen(corner) < this.last_seen && c.water_at(corner)) {
                        dfs.min_i = i;
                        dfs.flood(i, j, corner);
                    }
                }
            }
        }
        if (flush_undo) this.push_empty_undo();
        if (dfs.changes.length > 0) {
            this._push_undo_changes(dfs.changes, false);
        }
        return this.fix_invalid_boats(false) || dfs.changes.length > 0;
    }

    fix_invalid_boats(flush_undo: boolean = true): boolean {
        if (flush_undo) this.push_empty_undo();
        let removed_boat = false;
        for (let i = 0; i < this.n; i++) {
            for (let j = 0; j < this.m; j++) {
                const c = this.get_cell(i, j) as CellWithLoc;
                if (c._has_boat_invalid_pos()) {
                    c.remove_content(E.Corner.TopLeft, false);
                    removed_boat = true;
                }
            }
        }
        return removed_boat;
    }

    flood_nowater(flush_undo: boolean = true): boolean {
        if (flush_undo) this.push_empty_undo();
        const dfs = new AddNoWaterDfs(this);
        for (let i = this.n - 1; i >= 0; i--) {
            for (let j = 0; j < this.m; j++) {
                const c = this._pure_cell(i, j);
                for (const corner of [E.Corner.TopLeft, E.Corner.TopRight, E.Corner.BottomRight, E.Corner.BottomLeft]) {
                    if (c._valid_corner(corner) && c.last_seen(corner) < this.last_seen && c.nowater_at(corner)) {
                        dfs.flood(i, j, corner);
                    }
                }
            }
        }
        if (dfs.changes.length > 0) {
            this._push_undo_changes(dfs.changes, false);
            return true;
        }
        return false;
    }

    clear_content(): void {
        for (let i = 0; i < this.n; i++) {
            for (let j = 0; j < this.m; j++) {
                const c = this._pure_cell(i, j);
                if (c.c_left !== Content.Block) c.c_left = Content.Nothing;
                if (c.c_right !== Content.Block) c.c_right = Content.Nothing;
            }
        }
        this.undo_stack = [];
        this.redo_stack = [];
    }

    clear_all(): void {
        if (!this.editor_mode()) {
            return this.clear_content();
        }
        for (let i = 0; i < this.n; i++) {
            for (let j = 0; j < this.m; j++) {
                this.cell_hints[i][j] = null;
                this.pure_cells[i][j] = PureCell.empty();
                if (i < this.n - 1) this.wall_bottom[i][j] = false;
                if (j < this.m - 1) this.wall_right[i][j] = false;
            }
        }
        this.undo_stack = [];
        this.redo_stack = [];
        this.maybe_update_hints();
    }

    editor_mode(): boolean {
        return this._force_editor_mode || this.solution_c_left.length === 0;
    }

    force_editor_mode(b: boolean = true): void {
        this._force_editor_mode = b;
    }

    set_auto_update_hints(b: boolean): void {
        this.auto_update_hints_ = b;
        if (b) this.maybe_update_hints();
    }

    auto_update_hints(): boolean {
        return this.editor_mode() && this.auto_update_hints_;
    }

    export_data(): any {
        return new GridExporter().export_data(this);
    }

    _line_hint_eq(a: LineHint, b: LineHint): boolean {
        if (a.boat_count !== b.boat_count || a.boat_count_type !== b.boat_count_type) return false;
        if (a.water_count !== b.water_count || a.water_count_type !== b.water_count_type) return false;
        return true;
    }

    equal(other: GridImpl): boolean {
        if (this.n !== other.n || this.m !== other.m) return false;
        for (let i = 0; i < this.n; i++) {
            for (let j = 0; j < this.m; j++) {
                if (!this._pure_cell(i, j).equal(other._pure_cell(i, j))) return false;
            }
        }
        if (this._grid_hints.total_boats !== other._grid_hints.total_boats) return false;
        if (this._grid_hints.total_water !== other._grid_hints.total_water) return false;
        const aq1 = this._grid_hints.expected_aquariums || {};
        const aq2 = other._grid_hints.expected_aquariums || {};
        const keys1 = Object.keys(aq1);
        const keys2 = Object.keys(aq2);
        if (keys1.length !== keys2.length) return false;
        for (const k of keys1) {
            if (aq1[Number(k)] !== aq2[Number(k)]) return false;
        }
        for (let i = 0; i < this.n - 1; i++) {
            for (let j = 0; j < this.m; j++) {
                if (this.wall_bottom[i][j] !== other.wall_bottom[i][j]) return false;
            }
        }
        for (let i = 0; i < this.n; i++) {
            for (let j = 0; j < this.m - 1; j++) {
                if (this.wall_right[i][j] !== other.wall_right[i][j]) return false;
            }
        }
        for (let i = 0; i < this.n; i++) {
            if (!this._line_hint_eq(this._row_hints[i], other._row_hints[i])) return false;
        }
        for (let j = 0; j < this.m; j++) {
            if (!this._line_hint_eq(this._col_hints[j], other._col_hints[j])) return false;
        }
        return true;
    }

    is_empty(): boolean {
        return this.count_boats() <= 0 && this.count_waters() <= 0 && this.count_nowaters() <= 0;
    }

    copy_to_clipboard(): void {}

    merge_last_undo(): void {
        while (this.undo_stack.length > 0 && this.undo_stack[this.undo_stack.length - 1].changes.length === 0) {
            this.undo_stack.pop();
        }
        if (this.undo_stack.length < 2) return;
        const last = this.undo_stack.pop()!;
        this.undo_stack[this.undo_stack.length - 1].changes.push(...last.changes);
    }

    prettify_hints(is_procedurally_generated: boolean): void {}
    any_schrodinger_boats(): boolean { return false; }
    is_equal_solution(): boolean { return true; }

    _mirror_arr<T>(arr: T[], mirror_element: (el: T) => T): void {
        const sz = arr.length;
        for (let i = 0; i < Math.floor(sz / 2); i++) {
            const tmp = arr[i];
            arr[i] = mirror_element(arr[sz - 1 - i]);
            arr[sz - 1 - i] = mirror_element(tmp);
        }
        if ((sz & 1) === 1) {
            arr[Math.floor(sz / 2)] = mirror_element(arr[Math.floor(sz / 2)]);
        }
    }

    mirror_horizontal(): void {
        this.clear_content();
        for (let i = 0; i < this.rows(); i++) {
            this._mirror_arr(this.pure_cells[i], cell => { cell.mirror_horizontal(); return cell; });
            this._mirror_arr(this.cell_hints[i], c => c);
        }
        for (const row of this.wall_bottom) {
            this._mirror_arr(row, b => b);
        }
        for (const row of this.wall_right) {
            this._mirror_arr(row, b => b);
        }
        this.validate();
    }

    mirror_vertical(): void {
        this.rotate_clockwise();
        this.mirror_horizontal();
        this.rotate_counter();
    }

    _rotate_grid<T>(old: T[][], rotate_element: (el: T) => T): T[][] {
        const res: T[][] = [];
        if (old.length === 0) return res;
        const on = old.length;
        const om = old[0].length;
        for (let ni = 0; ni < om; ni++) {
            const row: T[] = new Array(on);
            for (let nj = 0; nj < on; nj++) {
                const oi = on - 1 - nj;
                const oj = ni;
                row[nj] = rotate_element(old[oi][oj]);
            }
            res.push(row);
        }
        return res;
    }

    _adjust_hints(arr: LineHint[], new_size: number): void {
        if (arr.length > new_size) {
            arr.length = new_size;
        }
        while (arr.length < new_size) {
            arr.push(this._empty_line_hint());
        }
    }

    rotate_clockwise(): void {
        this.clear_content();
        this.pure_cells = this._rotate_grid(this.pure_cells, cell => { cell.rotate_clock(); return cell; });
        this.cell_hints = this._rotate_grid(this.cell_hints, x => x);
        const new_wall_bottom = this._rotate_grid(this.wall_right, b => b);
        this.wall_right = this._rotate_grid(this.wall_bottom, b => b);
        this.wall_bottom = new_wall_bottom;
        this._adjust_hints(this.row_hints(), this.m);
        this._adjust_hints(this.col_hints(), this.n);
        const new_m = this.n;
        this.n = this.m;
        this.m = new_m;
        this.validate();
    }

    rotate_counter(): void {
        for (let i = 0; i < 3; i++) {
            this.rotate_clockwise();
        }
    }

    _is_content_partial_solution(c: Content, sol: Content): boolean {
        switch (c) {
            case Content.Block:
            case Content.Water:
            case Content.Boat:
                return sol === c;
            case Content.Nothing:
            case Content.NoWater:
            case Content.NoBoat:
            case Content.NoBoatWater:
                return true;
        }
        return true;
    }

    _is_content_equal_solution(c: Content, sol: Content): boolean {
        return this._is_content_partial_solution(c, sol) && this._is_content_partial_solution(sol, c);
    }

    _content_sol(i: number, j: number, corner: E.Corner): Content {
        if (E.corner_is_left(corner)) {
            return this.solution_c_left[i]?.[j] ?? Content.Nothing;
        } else {
            return this.solution_c_right[i]?.[j] ?? Content.Nothing;
        }
    }

    is_solution_partially_valid(): boolean {
        for (let i = 0; i < this.n; i++) {
            for (let j = 0; j < this.m; j++) {
                if (!this._is_content_partial_solution(this._pure_cell(i, j).c_left, this.solution_c_left[i]?.[j] ?? Content.Nothing)) {
                    return false;
                }
                if (!this._is_content_partial_solution(this._pure_cell(i, j).c_right, this.solution_c_right[i]?.[j] ?? Content.Nothing)) {
                    return false;
                }
            }
        }
        return true;
    }

    is_corner_partially_valid(c: Content, i: number, j: number, corner: E.Corner): boolean {
        return this.editor_mode() || this._is_content_partial_solution(c, this._content_sol(i, j, corner));
    }

    validate(): void {}
}