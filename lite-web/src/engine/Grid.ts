// src/engine/Grid.ts

import { E } from './E';
import { Vector2i, Vector3i } from './Math'; // We will define some basic math types
import { Content } from '../model/GridData';

export class LineHint {
    water_count: number = -1;
    water_count_type: E.HintType = E.HintType.Hidden;
    boat_count: number = -1;
    boat_count_type: E.HintType = E.HintType.Hidden;
    
    duplicate(): LineHint {
        const h = new LineHint();
        h.water_count = this.water_count;
        h.water_count_type = this.water_count_type;
        h.boat_count = this.boat_count;
        h.boat_count_type = this.boat_count_type;
        return h;
    }
}

export class GridHints {
    total_water: number = -1;
    total_boats: number = 0;
    expected_aquariums: Record<number, number> = {};
}

export class WaterPosition {
    i: number;
    j: number;
    loc: E.Waters;
    
    constructor(i: number, j: number, loc: E.Waters) {
        this.i = i;
        this.j = j;
        this.loc = loc;
    }
    
    static from_ij2(grid: GridModel, oi: number, oj2: number): WaterPosition {
        const type = grid.get_cell(oi, Math.floor(oj2 / 2)).cell_type();
        const side = (oj2 & 1) === 0 ? E.Side.Left : E.Side.Right;
        const corner = E.diag_to_corner(type, side);
        return new WaterPosition(oi, Math.floor(oj2 / 2), E.corner_to_waters(corner, type));
    }
    
    to_vec3(): Vector3i {
        return new Vector3i(this.i, this.j, this.loc);
    }
    
    j2(): number {
        switch (this.loc) {
            case E.Waters.Single:
            case E.Waters.TopLeft:
            case E.Waters.BottomLeft:
                return 2 * this.j;
            default:
                return 2 * this.j + 1;
        }
    }
    
    to_ij2(): Vector2i {
        return new Vector2i(this.i, this.j2());
    }
}

export class CellHints {
    adj_water_count: number = 0;
    adj_water_count_type: E.HintType = E.HintType.Hidden;
}

export abstract class CellModel {
    abstract water_full(): boolean;
    abstract water_at(corner: E.Corner): boolean;
    abstract nowater_full(): boolean;
    abstract noboat_full(): boolean;
    abstract noboatwater_full(): boolean;
    abstract nowater_at(corner: E.Corner): boolean;
    abstract noboat_at(corner: E.Corner): boolean;
    abstract nothing_full(): boolean;
    abstract nothing_at(corner: E.Corner): boolean;
    abstract block_full(): boolean;
    abstract block_at(corner: E.Corner): boolean;
    abstract wall_at(wall: E.Walls): boolean;
    
    abstract put_water(corner: E.Corner, flush_undo?: boolean): number;
    abstract put_nowater(corner: E.Corner, flush_undo?: boolean, flood?: boolean): boolean;
    abstract put_noboat(corner: E.Corner, flush_undo?: boolean): boolean;
    abstract put_block(corner: E.Corner, flush_undo?: boolean): boolean;
    
    abstract remove_content(corner: E.Corner, flush_undo?: boolean, flood_air?: boolean): void;
    abstract remove_nowater(corner: E.Corner, flush_undo?: boolean): void;
    abstract remove_noboat(corner: E.Corner, flush_undo?: boolean): void;
    
    abstract put_wall(wall: E.Walls, flush_undo?: boolean, unsafe_mode?: boolean): boolean;
    abstract remove_wall(wall: E.Walls, flush_undo?: boolean): boolean;
    
    abstract has_boat(): boolean;
    abstract put_boat(flush_undo?: boolean, flood?: boolean): boolean;
    
    abstract cell_type(): E.CellType;
    abstract corners(): E.Corner[];
    abstract waters(): E.Waters[];
    
    abstract water_would_flood_how_many(corner: E.Corner): number;
    abstract water_would_flood_which(corner: E.Corner, in_area?: any): WaterPosition[];
    
    abstract boat_possible(disallow_nowater_below?: boolean, only_permanent_content?: boolean): boolean;
    abstract boat_would_flood_which(): WaterPosition[];
    
    abstract nowater_would_flood_how_many(corner: E.Corner): number;
    
    abstract add_cell_hints(flush_undo?: boolean): boolean;
    abstract rem_cell_hints(flush_undo?: boolean): boolean;
    
    abstract hints(): CellHints;
    abstract hints_status(): E.HintStatus;
}

export enum LoadMode {
    Solution,
    SolutionNoClear,
    Editor,
    Testing,
    ContentOnly
}

export abstract class GridModel {
    abstract rows(): number;
    abstract cols(): number;
    abstract get_cell(i: number, j: number): CellModel;
    abstract wall_at(i: number, j: number, side: E.Side): boolean;
    abstract put_wall_from_idx(i1: number, j1: number, i2: number, j2: number, flush_undo?: boolean): boolean;
    abstract remove_wall_from_idx(i1: number, j1: number, i2: number, j2: number, flush_undo?: boolean): boolean;
    
    abstract row_hints(): LineHint[];
    abstract col_hints(): LineHint[];
    
    abstract add_row(flush_undo?: boolean): void;
    abstract rem_row(flush_undo?: boolean): void;
    abstract add_col(flush_undo?: boolean): void;
    abstract rem_col(flush_undo?: boolean): void;
    
    abstract get_expected_boats(): number;
    abstract get_expected_waters(): number;
    
    abstract all_boats_hint_status(): E.HintStatus;
    abstract all_waters_hint_status(): E.HintStatus;
    abstract all_hints_status(): E.HintStatus;
    
    abstract are_hints_satisfied(check_complete?: boolean): boolean;
    abstract is_any_hint_broken(): boolean;
    
    abstract get_row_hint_status(i: number, hint_type: E.HintContent): E.HintStatus;
    abstract get_col_hint_status(j: number, hint_type: E.HintContent): E.HintStatus;
    
    abstract count_water_row(i: number): number;
    abstract count_water_col(j: number): number;
    abstract count_boat_row(i: number): number;
    abstract count_boat_col(j: number): number;
    abstract count_water_adj(i: number, j: number): number;
    abstract count_nothing_adj(i: number, j: number): number;
    
    abstract grid_hints(): GridHints;
    abstract all_aquarium_counts(): Record<number, number>;
    abstract aquarium_hints_status(): E.HintStatus;
    
    abstract load_from_str(s: string, load_mode?: LoadMode): void;
    abstract to_str(): string;
    
    abstract undo(skip_empty?: boolean): boolean;
    abstract redo(skip_empty?: boolean): boolean;
    abstract push_empty_undo(): void;
    
    abstract flood_all(flush_undo?: boolean): boolean;
    abstract flood_nowater(flush_undo?: boolean): boolean;
    abstract clear_content(): void;
    abstract clear_all(): void;
    
    abstract editor_mode(): boolean;
    abstract force_editor_mode(b?: boolean): void;
    abstract set_auto_update_hints(b: boolean): void;
    
    abstract export_data(): any;
    
    abstract is_empty(): boolean;
    abstract copy_to_clipboard(): void;
    abstract merge_last_undo(): void;
    
    abstract count_waters(): number;
    abstract count_boats(): number;
    abstract count_blocks(): number;
    
    abstract prettify_hints(is_procedurally_generated: boolean): void;
    abstract check_complete(): boolean;
    abstract any_schrodinger_boats(): boolean;
    abstract is_equal_solution(): boolean;
    
    abstract mirror_horizontal(): void;
    abstract mirror_vertical(): void;
    abstract rotate_clockwise(): void;
    abstract rotate_counter(): void;
    
    abstract is_corner_partially_valid(c: Content, i: number, j: number, corner: E.Corner): boolean;
    abstract is_solution_partially_valid(): boolean;
}
