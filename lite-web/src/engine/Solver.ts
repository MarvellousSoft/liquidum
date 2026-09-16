import { E } from './E';
import { GridModel, LineHint, WaterPosition, CellHints } from './Grid';
import { Vector2i, Rect2i } from './Math';
import {
    GridImpl,
    Content,
    PureCell,
    CellWithLoc,
    Dfs,
    type AreaCheck,
    RectAreaCheck,
    AquariumInfo,
    CrawlAquarium,
    ComponentInfo,
    BaseAdjDfs,
    WaterAdjDfs
} from './GridImpl';
import { Ij2 } from './Ij2';
import { SubsetSum, OptionsSum } from './SubsetSum';

export abstract class Strategy {
    grid: GridImpl;
    constructor(grid: GridImpl) {
        this.grid = grid;
    }
    abstract apply_any(): boolean;
    description(): string {
        return "No description";
    }
}

export class SolverModel {
    static _maybe_infer_hint(grid: GridImpl, hints: LineHint[], a: number, is_row: boolean): LineHint {
        let h = hints[a];
        if (h.water_count === -1 && grid.grid_hints().total_water !== -1) {
            let inferred = grid.grid_hints().total_water;
            for (let b = 0; b < hints.length; b++) {
                if (b !== a) {
                    if (hints[b].water_count === -1) {
                        inferred = -1;
                        break;
                    }
                    inferred -= hints[b].water_count;
                }
            }
            if (inferred !== -1) {
                h = h.duplicate();
                h.water_count = inferred;
            }
        }
        if (h.boat_count === -1 && !is_row && h.boat_count_type === E.HintType.Together) {
            if (h === hints[a]) {
                h = h.duplicate();
            }
            h.boat_count = 1;
        }
        if (h.boat_count === -1 && grid.grid_hints().total_boats !== -1) {
            let inferred = grid.grid_hints().total_boats;
            for (let b = 0; b < hints.length; b++) {
                if (b !== a) {
                    if (hints[b].boat_count === -1) {
                        inferred = -1;
                        break;
                    }
                    inferred -= hints[b].boat_count;
                }
            }
            if (inferred !== -1 && h === hints[a]) {
                h = h.duplicate();
            }
            if (inferred !== -1) {
                h.boat_count = inferred;
            }
        }
        return h;
    }

    static _row_hint(grid: GridImpl, i: number): LineHint {
        return SolverModel._maybe_infer_hint(grid, grid.row_hints(), i, true);
    }

    static _col_hint(grid: GridImpl, j: number): LineHint {
        return SolverModel._maybe_infer_hint(grid, grid.col_hints(), j, false);
    }

    static _put_water(grid: GridImpl, pos: WaterPosition): boolean {
        const corner = pos.loc !== E.Waters.Single ? (pos.loc as unknown as E.Corner) : E.Corner.TopLeft;
        const c = grid.get_cell(pos.i, pos.j);
        if (!c.water_at(corner)) {
            const added = grid.get_cell(pos.i, pos.j).put_water(corner, false);
            return added > 0;
        }
        return false;
    }

    static _put_nowater(grid: GridImpl, pos: WaterPosition): boolean {
        const corner = pos.loc !== E.Waters.Single ? (pos.loc as unknown as E.Corner) : E.Corner.TopLeft;
        const c = grid.get_cell(pos.i, pos.j);
        if (!c.nowater_at(corner)) {
            const added = (c as CellWithLoc).put_nowater(corner, false, true);
            return added;
        }
        return false;
    }

    static _maybe_extra_boat_col(grid: GridImpl, j: number): boolean {
        const hint = SolverModel._col_hint(grid, j).boat_count;
        return hint === -1 || grid.count_boat_col(j) < hint;
    }

    static _maybe_extra_boat_on_row(grid: GridImpl, i: number): boolean {
        const hint = SolverModel._row_hint(grid, i).boat_count;
        return hint === -1 || grid.count_boat_row(i) < hint;
    }

    static _list_possible_boats_on_col(grid: GridImpl, j: number): Vector2i[] {
        let i = grid.rows() - 1;
        const ans: Vector2i[] = [];
        while (i >= 0) {
            let c = grid.get_cell(i, j);
            if (c.cell_type() !== E.CellType.Single) {
                i -= 1;
                continue;
            }
            const boat_possible = c.boat_possible();
            const had_boat = c.has_boat();
            if (!boat_possible) {
                i -= 1;
                continue;
            }
            const r = i;
            let l = i;
            let stop_moving = c.nowater_full();
            let any_possible = !had_boat && SolverModel._maybe_extra_boat_on_row(grid, i);
            i -= 1;
            while (i >= 0 && grid.get_cell(i, j).cell_type() === E.CellType.Single && !grid.get_cell(i, j).wall_at(E.Walls.Bottom)) {
                c = grid.get_cell(i, j);
                if (!stop_moving && c.nothing_full()) {
                    l = i;
                }
                if (!stop_moving && c.nowater_full()) {
                    l = i;
                    stop_moving = true;
                }
                if (l === i) {
                    any_possible = any_possible || (!had_boat && SolverModel._maybe_extra_boat_on_row(grid, i));
                }
                i -= 1;
            }
            if (any_possible) {
                ans.push(new Vector2i(l, r));
            }
        }
        return ans;
    }

    static _put_boat_on_col(grid: GridImpl, lr: Vector2i, j: number): boolean {
        let any = false;
        let possible_i = -1;
        for (let i = lr.x; i <= lr.y; i++) {
            if (possible_i !== -2 && SolverModel._maybe_extra_boat_on_row(grid, i)) {
                if (possible_i === -1) {
                    possible_i = i;
                } else {
                    possible_i = -2;
                }
            }
        }
        if (possible_i >= 0) {
            if (grid.get_cell(possible_i, j).put_boat(false, true)) {
                any = true;
            }
        } else {
            if (grid.get_cell(lr.x, j).nothing_full()) {
                if ((grid.get_cell(lr.x, j) as CellWithLoc).put_nowater(E.Corner.TopLeft, false, true)) {
                    any = true;
                }
            }
            if (grid._pure_cell(lr.y + 1, j)._content_top() !== Content.Water) {
                const c = grid.get_cell(lr.y + 1, j);
                if (c.put_water(E.diag_to_corner(c.cell_type(), E.Side.Top), false)) {
                    any = true;
                }
            }
        }
        return any;
    }

    static generic_solve(grid: GridImpl, advanced: boolean, water_hint: number, area_check: AreaCheck): boolean {
        const rect_aqs: AquariumInfo[] = [];
        const dfs = new CrawlAquarium(grid, area_check, true);
        const last_seen = grid.last_seen;
        let any_pools = false;
        let total_empty = 0.0;
        let total_water = 0.0;
        const grid_rect = new Rect2i(0, 0, grid.rows(), grid.cols());

        const points = area_check.all_points ? area_check.all_points() : [];
        for (const pos of points) {
            if (!grid_rect.has_point(pos)) continue;
            const i2 = pos.x;
            const j2 = pos.y;
            for (const corner of grid.get_cell(i2, j2).corners()) {
                const c = grid._pure_cell(i2, j2);
                if (c.last_seen(corner) < last_seen && !c.block_at(corner) && !c.nowater_at(corner)) {
                    dfs.reset();
                    dfs.flood(i2, j2, corner);
                    dfs.reset_for_pool_check();
                    dfs.flood(i2, j2, corner);
                    rect_aqs.push(dfs.info);
                    total_empty += dfs.info.total_empty;
                    total_water += dfs.info.total_water;
                    any_pools = any_pools || dfs.info.has_pool;
                }
            }
        }

        if (water_hint < total_water || total_empty === 0) {
            return false;
        }

        let any = false;
        if (!advanced) {
            for (const aq of rect_aqs) {
                if (aq.has_pool) continue;
                for (let di = 0; di < aq.empty_at_height.length; di++) {
                    if (aq.empty_at_height[di] === 0) continue;
                    if (total_empty - aq.total_empty < water_hint - total_water) {
                        any = true;
                        for (const pos of aq.cells_at_height[di]) {
                            SolverModel._put_water(grid, pos);
                        }
                        total_water += aq.empty_at_height[di];
                        aq.total_water += aq.empty_at_height[di];
                        total_empty -= aq.empty_at_height[di];
                        aq.total_empty -= aq.empty_at_height[di];
                        aq.empty_at_height[di] = 0.0;
                    } else {
                        break;
                    }
                }
                for (let di = aq.empty_at_height.length - 1; di >= 0; di--) {
                    if (aq.empty_at_height[di] === 0) continue;
                    if (aq.total_empty > water_hint - total_water) {
                        any = true;
                        for (const pos of aq.cells_at_height[di]) {
                            SolverModel._put_nowater(grid, pos);
                        }
                        total_empty -= aq.empty_at_height[di];
                        aq.total_empty -= aq.empty_at_height[di];
                        aq.empty_at_height[di] = 0.0;
                    } else {
                        break;
                    }
                }
            }
        } else {
            if (!any_pools) {
                const options: number[][] = [];
                const opt_to_aq = new Map<string, AquariumInfo>();
                for (const aq of rect_aqs) {
                    if (aq.total_empty === 0) continue;
                    const opt = [0.0];
                    for (const x of aq.empty_at_height) {
                        if (x === 0) continue;
                        opt.push(opt[opt.length - 1] + x);
                    }
                    opt_to_aq.set(opt.join(','), aq);
                    options.push(opt);
                }
                const cmpOpt = (a: number[], b: number[]) => {
                    for (let i = 0; i < Math.min(a.length, b.length); i++) {
                        if (a[i] !== b[i]) return a[i] - b[i];
                    }
                    return a.length - b.length;
                };
                options.sort(cmpOpt);
                const water_needed = water_hint - total_water;
                if (!OptionsSum.can_be_solved(water_needed, options)) {
                    return false;
                }
                for (let idx = 0; idx < options.length; idx++) {
                    for (let jdx = 0; jdx < options[idx].length; jdx++) {
                        const new_opts = options.map(o => [...o]);
                        new_opts[idx].splice(jdx, 1);
                        new_opts.sort(cmpOpt);
                        if (!OptionsSum.can_be_solved(water_needed, new_opts)) {
                            const aq = opt_to_aq.get(options[idx].join(','))!;
                            let water = options[idx][jdx];
                            for (let kdx = 0; kdx < aq.empty_at_height.length; kdx++) {
                                if (aq.empty_at_height[kdx] === 0) continue;
                                if (water > 0) {
                                    water -= aq.empty_at_height[kdx];
                                    for (const pos of aq.cells_at_height[kdx]) {
                                        SolverModel._put_water(grid, pos);
                                    }
                                } else {
                                    for (const pos of aq.cells_at_height[kdx]) {
                                        SolverModel._put_nowater(grid, pos);
                                    }
                                }
                            }
                            return true;
                        } else if (options[idx].length > 2 && (jdx === 0 || jdx === options[idx].length - 1)) {
                            const new_opts2 = options.map(o => [...o]);
                            new_opts2.splice(idx, 1);
                            if (!OptionsSum.can_be_solved(water_needed - options[idx][jdx], new_opts2)) {
                                const aq = opt_to_aq.get(options[idx].join(','))!;
                                if (jdx === 0) {
                                    for (let kdx = 0; kdx < aq.empty_at_height.length; kdx++) {
                                        if (aq.empty_at_height[kdx] > 0) {
                                            for (const pos of aq.cells_at_height[kdx]) {
                                                SolverModel._put_water(grid, pos);
                                            }
                                            break;
                                        }
                                    }
                                } else {
                                    for (let kdx = aq.empty_at_height.length - 1; kdx >= 0; kdx--) {
                                        if (aq.empty_at_height[kdx] > 0) {
                                            for (const pos of aq.cells_at_height[kdx]) {
                                                SolverModel._put_nowater(grid, pos);
                                            }
                                            break;
                                        }
                                    }
                                }
                                return true;
                            }
                        }
                    }
                }
            }
        }
        return any;
    }

    static can_separate_aqs(l: AquariumInfo, r: AquariumInfo): boolean {
        let leftAq = l;
        let rightAq = r;
        if (leftAq.cells_at_height[0][0].j > rightAq.cells_at_height[0][0].j) {
            const tmp = leftAq;
            leftAq = rightAq;
            rightAq = tmp;
        }
        const lr2 = leftAq.cells_at_height[0][leftAq.cells_at_height[0].length - 1].j2();
        const rl2 = rightAq.cells_at_height[0][0].j2();
        if (leftAq.max_i === rightAq.max_i) {
            return rl2 > lr2 + 1;
        } else if (Math.abs(leftAq.max_i - rightAq.max_i) === 1) {
            return rl2 > lr2;
        } else {
            return true;
        }
    }

    static is_cellhint_separated_impossible(grid: GridImpl, ci: number, cj: number, hint: CellHints): boolean {
        if (hint.adj_water_count >= 0 && grid.count_water_adj(ci, cj) === hint.adj_water_count) {
            return grid.together_waters_adj(hint.adj_water_count, ci, cj) === E.HintType.Together;
        }
        const dfs = new ComponentAdjDfs(grid, ci, cj);
        let cmp: ComponentInfo | null = null;
        for (let i = ci - 1; i <= ci + 1; i++) {
            for (let j2 = 2 * cj - 2; j2 <= 2 * cj + 3; j2++) {
                if (dfs.flood(i, j2)) {
                    if (cmp !== null) {
                        return false;
                    }
                    cmp = dfs.info;
                }
            }
        }
        if (cmp === null) return true;
        if (hint.adj_water_count >= 0 && hint.adj_water_count >= cmp.total_water + cmp.total_empty) {
            return true;
        }
        const wdfs = new WaterAdjDfs(grid, ci, cj);
        wdfs.calc_component_info();
        let wcmp: ComponentInfo | null = null;
        for (let i = ci - 1; i <= ci + 1; i++) {
            for (let j2 = 2 * cj - 2; j2 <= 2 * cj + 3; j2++) {
                if (wdfs.flood(i, j2)) {
                    if (wcmp !== null) {
                        return false;
                    }
                    wcmp = wdfs.info;
                }
            }
        }
        const area = new RectAreaCheck(new Rect2i(ci - 1, cj - 1, 3, 3));
        if (wcmp !== null) {
            const propdfs = new PropagateAdjacentEmptiesDfs(grid, area);
            for (const pos of wcmp.neighbors) {
                const corner = E.waters_to_corner(pos.loc);
                const content = grid._pure_cell(pos.i, pos.j)._content_at(corner);
                if (content === Content.Nothing || content === Content.NoBoat) {
                    propdfs.flood(pos.i, pos.j, corner);
                }
            }
            for (let i = ci - 1; i <= ci + 1; i++) {
                for (let j = cj - 1; j <= cj + 1; j++) {
                    if (!grid.inside(i, j)) continue;
                    const c = grid._pure_cell(i, j);
                    for (const corner of c.corners()) {
                        const content = c._content_at(corner);
                        if (c.last_seen(corner) < grid.last_seen && (content === Content.Nothing || content === Content.NoBoat)) {
                            return false;
                        }
                    }
                }
            }
            return true;
        } else {
            const rect_aqs: AquariumInfo[] = [];
            const aqdfs = new CrawlAquarium(grid, area, false);
            const last_seen = grid.last_seen;
            for (let i = ci + 1; i >= ci - 1; i--) {
                for (let j = cj - 1; j <= cj + 1; j++) {
                    if (!grid.inside(i, j)) continue;
                    for (const corner of grid.get_cell(i, j).corners()) {
                        const c = grid._pure_cell(i, j);
                        const content = c._content_at(corner);
                        if (c.last_seen(corner) < last_seen && (content === Content.Nothing || content === Content.NoBoat)) {
                            aqdfs.reset();
                            aqdfs.flood(i, j, corner);
                            aqdfs.reset_for_pool_check();
                            aqdfs.flood(i, j, corner);
                            if (aqdfs.info.has_pool) {
                                return false;
                            }
                            rect_aqs.push(aqdfs.info);
                            if (rect_aqs.length > 3) {
                                return false;
                            }
                        }
                    }
                }
            }
            for (let l = 0; l < rect_aqs.length - 1; l++) {
                for (let r = l + 1; r < rect_aqs.length; r++) {
                    if (SolverModel.can_separate_aqs(rect_aqs[l], rect_aqs[r])) {
                        return false;
                    }
                }
            }
            return true;
        }
    }

    static STRATEGY_LIST: Record<string, (grid: GridImpl) => Strategy> = {
        BasicRow: (grid) => new BasicRowStrategy(grid),
        BasicCol: (grid) => new BasicColStrategy(grid),
        FullPropagateNoWater: (grid) => new FullPropagateNoWater(grid),
        BoatRow: (grid) => new BoatRowStrategy(grid),
        BoatCol: (grid) => new BoatColStrategy(grid),
        MediumRow: (grid) => new MediumRowStrategy(grid),
        MediumCol: (grid) => new MediumColStrategy(grid),
        AdvancedRow: (grid) => new AdvancedRowStrategy(grid),
        AdvancedCol: (grid) => new AdvancedColStrategy(grid),
        TogetherRowBasic: (grid) => new TogetherRowStrategy(grid, true),
        TogetherRowAdvanced: (grid) => new TogetherRowStrategy(grid, false),
        TogetherColBasic: (grid) => new TogetherColStrategy(grid, true),
        TogetherColAdvanced: (grid) => new TogetherColStrategy(grid, false),
        SeparateRowBasic: (grid) => new SeparateRowStrategy(grid, true),
        SeparateRowAdvanced: (grid) => new SeparateRowStrategy(grid, false),
        SeparateColBasic: (grid) => new SeparateColStrategy(grid, true),
        SeparateColAdvanced: (grid) => new SeparateColStrategy(grid, false),
        AllWatersEasy: (grid) => new AllWatersEasyStrategy(grid),
        AllWatersMedium: (grid) => new AllWatersMediumStrategy(grid),
        AllBoats: (grid) => new AllBoatsStrategy(grid),
        AquariumsBasic: (grid) => new AquariumsStrategy(grid, true),
        AquariumsAdvanced: (grid) => new AquariumsStrategy(grid, false),
        CellBasic: (grid) => new CellHintsBasic(grid),
        CellMedium: (grid) => new CellHintsMore(grid, false),
        TwoCellMedium: (grid) => new TwoCellHints(grid, false),
        CellAdvanced: (grid) => new CellHintsMore(grid, true),
        TwoCellAdvanced: (grid) => new TwoCellHints(grid, true),
        BasicTogetherCellHints: (grid) => new BasicTogetherCellHintsStrategy(grid),
        TogetherSeparateCellHints: (grid) => new TogetherSeparateCellHintsStrategy(grid),
    };

    apply_strategies(grid: GridImpl, strategies_names: string[], flush_undo: boolean = true, once: boolean = false): boolean {
        if (flush_undo) {
            grid.push_empty_undo();
        }
        grid.flood_nowater(false);
        const strategies: Record<string, Strategy> = {};
        for (const name of strategies_names) {
            if (SolverModel.STRATEGY_LIST[name]) {
                strategies[name] = SolverModel.STRATEGY_LIST[name](grid);
            }
        }
        for (let t = 0; t < 50; t++) {
            let any = false;
            for (const name of strategies_names) {
                if (strategies[name] && strategies[name].apply_any()) {
                    if (once) return true;
                    any = true;
                    break;
                }
            }
            if (!any) {
                return t > 0;
            }
        }
        return true;
    }

    can_solve_with_strategies(grid: GridImpl, strategies_names: string[], forced_strategies_or: string[]): boolean {
        grid.force_editor_mode();
        const names = [...strategies_names];
        for (const s of forced_strategies_or) {
            if (!names.includes(s)) {
                names.push(s);
            }
        }
        while (true) {
            this.apply_strategies(grid, names, false);
            if (grid.check_complete()) {
                const status = grid.all_hints_status();
                if (status === E.HintStatus.Wrong) {
                    return false;
                }
                if (status === E.HintStatus.Satisfied) {
                    break;
                }
            }
            return false;
        }
        grid.clear_content();
        this.apply_strategies(grid, names);
        if (!grid.are_hints_satisfied(true)) {
            return false;
        }
        if (forced_strategies_or.length === 0) {
            return true;
        }
        grid.clear_content();
        this.apply_strategies(grid, names.filter(s2 => !forced_strategies_or.includes(s2)), false);
        if (grid.are_hints_satisfied()) {
            return false;
        }
        return true;
    }

    full_solve(
        grid: GridImpl,
        strategy_list: string[],
        cancel_sig: () => boolean,
        flush_undo: boolean = true,
        guesses_left: number = 2,
        min_boat_place: Vector2i = new Vector2i(0, 0),
        look_for_multiple: boolean = true
    ): SolveResult {
        if (flush_undo) {
            grid.push_empty_undo();
        }
        if (cancel_sig() || guesses_left < 0) {
            return SolveResult.GaveUp;
        }
        this.apply_strategies(grid, strategy_list, false);
        const status = grid.all_hints_status();
        if (status === E.HintStatus.Wrong) {
            return SolveResult.Unsolvable;
        }
        if (status === E.HintStatus.Satisfied && grid.check_complete()) {
            if (grid.any_schrodinger_boats()) {
                return SolveResult.SolvedMultiple;
            }
            return SolveResult.SolvedUniqueNoGuess;
        }
        for (let i = 0; i < grid.rows(); i++) {
            for (let j = 0; j < grid.cols(); j++) {
                for (const corner of [E.Corner.TopLeft, E.Corner.TopRight, E.Corner.BottomRight, E.Corner.BottomLeft]) {
                    const c = grid.get_cell(i, j);
                    if (c.nothing_at(corner)) {
                        c.put_water(corner, true);
                        const r1 = this.full_solve(grid, strategy_list, cancel_sig, false, guesses_left - 1, min_boat_place, look_for_multiple);
                        grid.undo();
                        if (r1 === SolveResult.Unsolvable) {
                            (c as CellWithLoc).put_nowater(corner, false);
                            return this._make_guess(this.full_solve(grid, strategy_list, cancel_sig, false, guesses_left, min_boat_place, look_for_multiple));
                        } else if (!look_for_multiple || r1 === SolveResult.SolvedMultiple || r1 === SolveResult.GaveUp) {
                            grid.redo();
                            return r1;
                        }
                        (c as CellWithLoc).put_nowater(corner, true, true);
                        const r2 = this.full_solve(grid, strategy_list, cancel_sig, false, guesses_left - 1, min_boat_place, false);
                        if (r2 === SolveResult.Unsolvable) {
                            grid.undo();
                            c.put_water(corner, false);
                            return this._make_guess(this.full_solve(grid, strategy_list, cancel_sig, false, guesses_left, min_boat_place, look_for_multiple));
                        }
                        return SolveResult.SolvedMultiple;
                    }
                }
            }
        }
        for (let i = 0; i < grid.rows(); i++) {
            if (grid.get_row_hint_status(i, E.HintContent.Water) === E.HintStatus.Wrong) {
                return SolveResult.Unsolvable;
            }
        }
        for (let j = 0; j < grid.cols(); j++) {
            if (grid.get_col_hint_status(j, E.HintContent.Water) === E.HintStatus.Wrong) {
                return SolveResult.Unsolvable;
            }
        }
        if (grid.all_waters_hint_status() === E.HintStatus.Wrong || grid.aquarium_hints_status() === E.HintStatus.Wrong) {
            return SolveResult.Unsolvable;
        }
        for (let i = 0; i < grid.rows(); i++) {
            for (let j = 0; j < grid.cols(); j++) {
                const c = grid.get_cell(i, j);
                if ((i < min_boat_place.x || (i === min_boat_place.x && j < min_boat_place.y)) || !c.boat_possible() || c.has_boat()) {
                    continue;
                }
                const b = c.put_boat(true, true);
                if (b) {
                    const r1 = this.full_solve(grid, strategy_list, cancel_sig, false, guesses_left - 1, new Vector2i(i, j + 1), look_for_multiple);
                    grid.undo();
                    if (r1 === SolveResult.Unsolvable) {
                        return this._make_guess(this.full_solve(grid, strategy_list, cancel_sig, false, guesses_left, new Vector2i(i, j + 1), look_for_multiple));
                    } else if (!look_for_multiple || r1 === SolveResult.SolvedMultiple || r1 === SolveResult.GaveUp) {
                        grid.redo();
                        return r1;
                    }
                    c.put_boat(false, true);
                    const r2 = this.full_solve(grid, strategy_list, cancel_sig, true, guesses_left - 1, new Vector2i(i, j + 1), false);
                    grid.undo(false);
                    if (r2 === SolveResult.Unsolvable) {
                        c.put_boat(false, true);
                        return this._make_guess(this.full_solve(grid, strategy_list, cancel_sig, false, guesses_left, new Vector2i(i, j + 1), look_for_multiple));
                    } else {
                        grid.redo(false);
                        return SolveResult.SolvedMultiple;
                    }
                }
            }
        }
        return SolveResult.Unsolvable;
    }

    private _make_guess(res: SolveResult): SolveResult {
        if (res === SolveResult.SolvedUniqueNoGuess) {
            return SolveResult.SolvedUnique;
        }
        return res;
    }
}

export enum SolveResult {
    SolvedUniqueNoGuess,
    SolvedUnique,
    SolvedMultiple,
    Unsolvable,
    GaveUp
}

export class AddNoWaterThroughDips extends Dfs {
    min_i: number = 0;
    any: boolean = false;

    reset(min_i_: number): void {
        this.min_i = min_i_;
        this.any = false;
    }

    _cell_logic(i: number, _j: number, corner: E.Corner, cell: PureCell): boolean {
        const c = cell._content_at(corner);
        switch (c) {
            case Content.Nothing:
            case Content.NoBoat:
                if (i <= this.min_i) {
                    cell.put_nowater(corner, false);
                    this.any = true;
                }
                break;
            case Content.Block:
            case Content.Boat:
            case Content.NoWater:
            case Content.NoBoatWater:
            case Content.Water:
                break;
        }
        return true;
    }

    _can_go_up(_i: number, _j: number): boolean {
        return true;
    }

    _can_go_down(i: number, _j: number): boolean {
        return i >= this.min_i;
    }
}

export class FullPropagateNoWater extends Strategy {
    description(): string {
        return "Propagate NoWater even through walls (in upper caves).";
    }

    apply_any(): boolean {
        const dfs = new AddNoWaterThroughDips(this.grid);
        for (let i = this.grid.rows() - 1; i >= 0; i--) {
            for (let j = 0; j < this.grid.cols(); j++) {
                const c = this.grid._pure_cell(i, j);
                for (const corner of c.corners()) {
                    const cont = c._content_at(corner);
                    if (cont === Content.NoWater || cont === Content.NoBoatWater) {
                        c.set_last_seen(corner, 0);
                        dfs.reset(i);
                        dfs.flood(i, j, corner);
                    }
                }
            }
        }
        this.grid._push_undo_changes(dfs.changes, false);
        return dfs.changes.length > 0;
    }
}

export class RowComponent {
    size: number = 0;
    first: CellWithLoc;
    corner: E.Corner;

    constructor(first_: CellWithLoc, corner_: E.Corner) {
        this.first = first_;
        this.corner = corner_;
    }

    put_water(): void {
        this.first.put_water(this.corner, false);
    }

    put_nowater(): void {
        this.first.put_nowater(this.corner, false, true);
    }
}

export class RowDfs extends Dfs {
    row_i: number;
    comp!: RowComponent;

    constructor(i: number, grid_: GridImpl) {
        super(grid_);
        this.row_i = i;
    }

    _cell_logic(i: number, _j: number, corner: E.Corner, cell: PureCell): boolean {
        if (cell.block_at(corner) || cell.nowater_at(corner)) {
            return false;
        }
        if (i === this.row_i && !cell.water_at(corner)) {
            this.comp.size += (1 + (cell.type === E.CellType.Single ? 1 : 0)) * 0.5;
        }
        return true;
    }

    _can_go_up(i: number, _j: number): boolean {
        return i > this.row_i;
    }

    _can_go_down(_i: number, _j: number): boolean {
        return true;
    }
}

export abstract class RowStrategy extends Strategy {
    abstract _apply_strategy(i: number, values: RowComponent[], water_left: number, nothing_left: number): boolean;

    _apply(i: number): boolean {
        const water_hint = SolverModel._row_hint(this.grid, i).water_count;
        if (water_hint < 0) return false;
        const dfs = new RowDfs(i, this.grid);
        const comps: RowComponent[] = [];
        for (let j = 0; j < this.grid.cols(); j++) {
            for (const corner of [E.Corner.TopLeft, E.Corner.BottomLeft, E.Corner.TopRight, E.Corner.BottomRight]) {
                const cell = this.grid._pure_cell(i, j);
                if (cell.last_seen(corner) < this.grid.last_seen && cell._valid_corner(corner) && cell.nothing_at(corner)) {
                    dfs.comp = new RowComponent(this.grid.get_cell(i, j) as CellWithLoc, corner);
                    dfs.flood(i, j, corner);
                    if (dfs.comp.size > 0) {
                        comps.push(dfs.comp);
                    }
                }
            }
        }
        let nothing_left = 0;
        for (let j = 0; j < this.grid.cols(); j++) {
            nothing_left += this.grid._pure_cell(i, j).nothing_count();
        }
        const water_left = water_hint - this.grid.count_water_row(i);
        if (nothing_left === 0 || comps.length === 0 || water_left > nothing_left || water_left < 0) {
            return false;
        }
        return this._apply_strategy(i, comps, water_left, nothing_left);
    }

    apply_any(): boolean {
        let any = false;
        for (let i = 0; i < this.grid.rows(); i++) {
            if (this._apply(i)) {
                any = true;
            }
        }
        return any;
    }
}

export class CellPosition {
    i: number;
    j: number;
    corner: E.Corner;

    constructor(i_: number, j_: number, corner_: E.Corner) {
        this.i = i_;
        this.j = j_;
        this.corner = corner_;
    }
}

export class ColComponent {
    size: number = 0;
    cells: CellPosition[] = [];

    put_water_on(grid: GridImpl, count: number): void {
        for (const c of this.cells) {
            count -= grid._pure_cell(c.i, c.j)._content_count_from(Content.Nothing, c.corner);
            if (count <= 0) {
                grid.get_cell(c.i, c.j).put_water(c.corner, false);
                return;
            }
        }
    }

    put_nowater_on(grid: GridImpl, count: number): void {
        for (let idx = 0; idx < this.cells.length; idx++) {
            const c = this.cells[this.cells.length - 1 - idx];
            count -= grid._pure_cell(c.i, c.j)._content_count_from(Content.Nothing, c.corner);
            if (count <= 0) {
                (grid.get_cell(c.i, c.j) as CellWithLoc).put_nowater(c.corner, false, true);
                return;
            }
        }
    }
}

export class ColDfs extends Dfs {
    col_j: number;
    comp!: ColComponent;

    constructor(j: number, grid_: GridImpl) {
        super(grid_);
        this.col_j = j;
    }

    _cell_logic(i: number, j: number, corner: E.Corner, cell: PureCell): boolean {
        if (cell.block_at(corner) || cell.nowater_at(corner)) {
            return false;
        }
        const nothing = cell._content_count_from(Content.Nothing, corner);
        if (j === this.col_j && nothing > 0) {
            this.comp.size += nothing;
            this.comp.cells.push(new CellPosition(i, j, corner));
        }
        return true;
    }

    _can_go_up(_i: number, _j: number): boolean { return true; }
    _can_go_down(_i: number, _j: number): boolean { return false; }
}

export abstract class ColumnStrategy extends Strategy {
    abstract _apply_strategy(values: ColComponent[], water_left: number, nothing_left: number): boolean;

    _apply(j: number): boolean {
        const hint = SolverModel._col_hint(this.grid, j).water_count;
        if (hint < 0) return false;
        const dfs = new ColDfs(j, this.grid);
        const comps: ColComponent[] = [];
        for (let i = this.grid.rows() - 1; i >= 0; i--) {
            for (const corner of [E.Corner.TopLeft, E.Corner.TopRight, E.Corner.BottomRight, E.Corner.BottomLeft]) {
                const cell = this.grid._pure_cell(i, j);
                if (cell.last_seen(corner) < this.grid.last_seen && cell._valid_corner(corner) && cell.nothing_at(corner)) {
                    dfs.comp = new ColComponent();
                    dfs.flood(i, j, corner);
                    if (dfs.comp.size > 0) {
                        dfs.comp.cells.sort((c1, c2) => c2.i - c1.i);
                        comps.push(dfs.comp);
                    }
                }
            }
        }
        let nothing_left = 0;
        for (let i = 0; i < this.grid.rows(); i++) {
            nothing_left += this.grid._pure_cell(i, j).nothing_count();
        }
        const water_left = hint - this.grid.count_water_col(j);
        if (nothing_left === 0 || comps.length === 0 || water_left > nothing_left || water_left < 0) {
            return false;
        }
        return this._apply_strategy(comps, water_left, nothing_left);
    }

    apply_any(): boolean {
        let any = false;
        for (let j = 0; j < this.grid.cols(); j++) {
            if (this._apply(j)) {
                any = true;
            }
        }
        return any;
    }
}

export class BasicRowStrategy extends RowStrategy {
    _apply_strategy(_i: number, values: RowComponent[], water_left: number, nothing_left: number): boolean {
        if (water_left === nothing_left) {
            for (const comp of values) {
                comp.put_water();
            }
            return true;
        }
        let any = false;
        for (const comp of values) {
            if (comp.size > water_left) {
                comp.put_nowater();
                any = true;
            }
        }
        return any;
    }
}

export class MediumRowStrategy extends RowStrategy {
    _apply_strategy(_i: number, values: RowComponent[], water_left: number, nothing_left: number): boolean {
        let any = false;
        for (const comp of values) {
            if (comp.size <= water_left && (nothing_left - comp.size) < water_left) {
                comp.put_water();
                any = true;
            }
        }
        return any;
    }
}

export class AdvancedRowStrategy extends RowStrategy {
    _apply_strategy(_i: number, values: RowComponent[], water_left: number, _nothing_left: number): boolean {
        const numbers: number[] = [];
        const size_to_cmp = new Map<number, RowComponent[]>();
        for (const c of values) {
            numbers.push(c.size);
            const cmps = size_to_cmp.get(c.size) || [];
            cmps.push(c);
            size_to_cmp.set(c.size, cmps);
        }
        let any = false;
        for (const [size, cmps] of size_to_cmp.entries()) {
            const next_nums = [...numbers];
            const idx = next_nums.indexOf(size);
            if (idx !== -1) next_nums.splice(idx, 1);
            if (!SubsetSum.can_be_solved(water_left, next_nums)) {
                for (const cmp of cmps) {
                    cmp.put_water();
                }
                any = true;
            } else if (!SubsetSum.can_be_solved(water_left - size, next_nums)) {
                for (const cmp of cmps) {
                    cmp.put_nowater();
                }
                any = true;
            }
        }
        return any;
    }
}

export class BasicColStrategy extends ColumnStrategy {
    _apply_strategy(values: ColComponent[], water_left: number, nothing_left: number): boolean {
        if (water_left === nothing_left) {
            for (const comp of values) {
                comp.put_water_on(this.grid, comp.size);
            }
            return true;
        }
        let any = false;
        for (const comp of values) {
            if (comp.size > water_left) {
                comp.put_nowater_on(this.grid, comp.size - water_left);
                any = true;
            }
        }
        return any;
    }
}

export class MediumColStrategy extends ColumnStrategy {
    _apply_strategy(values: ColComponent[], water_left: number, nothing_left: number): boolean {
        let any = false;
        for (const comp of values) {
            if (nothing_left - comp.size < water_left) {
                comp.put_water_on(this.grid, water_left - (nothing_left - comp.size));
                any = true;
            }
        }
        return any;
    }
}

export class AdvancedColStrategy extends ColumnStrategy {
    _apply_strategy(_values: ColComponent[], _water_left: number, _nothing_left: number): boolean {
        return false;
    }

    _apply(j: number): boolean {
        const hint = SolverModel._col_hint(this.grid, j).water_count;
        if (hint <= 0) return false;
        const water_left = hint - this.grid.count_water_col(j);
        if (water_left <= 0) return false;
        let single_i = -1;
        let single_corner = E.Corner.TopLeft;
        for (let i = 0; i < this.grid.rows(); i++) {
            const c = this.grid.get_cell(i, j);
            if (c.cell_type() !== E.CellType.Single) {
                for (const corner of c.corners()) {
                    if (c.nothing_at(corner)) {
                        if (single_i === -1) {
                            single_i = i;
                            single_corner = corner;
                        } else {
                            single_i = -2;
                        }
                    }
                }
            }
        }
        if (single_i >= 0) {
            if (water_left - Math.floor(water_left) === 0.5) {
                return this.grid.get_cell(single_i, j).put_water(single_corner, false) > 0;
            } else {
                return (this.grid.get_cell(single_i, j) as CellWithLoc).put_nowater(single_corner, false, true);
            }
        }
        return false;
    }
}

export class BoatRowStrategy extends RowStrategy {
    _apply_strategy(_i: number, _values: RowComponent[], _water_left: number, _nothing_left: number): boolean {
        return false;
    }

    _apply(i: number): boolean {
        const full_hint = SolverModel._row_hint(this.grid, i);
        let hint = full_hint.boat_count;
        if (hint === -1) {
            if (full_hint.boat_count_type === E.HintType.Together) {
                hint = 1;
                let first_boat = -1;
                let last_boat = -1;
                for (let j = 0; j < this.grid.cols(); j++) {
                    if (this.grid.get_cell(i, j).has_boat()) {
                        last_boat = j;
                        if (first_boat === -1) {
                            first_boat = j;
                        }
                    }
                }
                if (first_boat !== -1) {
                    let any = false;
                    for (let j = first_boat; j <= last_boat; j++) {
                        const c = this.grid.get_cell(i, j);
                        if (!c.has_boat()) {
                            if (c.boat_possible() && SolverModel._maybe_extra_boat_col(this.grid, j)) {
                                if (c.put_boat(false, true)) {
                                    any = true;
                                }
                            } else {
                                return false;
                            }
                        }
                    }
                    if (any) return true;
                }
            } else if (full_hint.boat_count_type === E.HintType.Separated) {
                hint = 2;
            }
        }
        if (hint <= 0) return false;
        let count = 0;
        for (let j = 0; j < this.grid.cols(); j++) {
            const c = this.grid.get_cell(i, j);
            if (c.has_boat()) {
                hint -= 1;
            } else if (c.boat_possible() && SolverModel._maybe_extra_boat_col(this.grid, j)) {
                count += 1;
            }
        }
        if (hint > 0 && count === hint) {
            let any = false;
            for (let j = 0; j < this.grid.cols(); j++) {
                const c = this.grid.get_cell(i, j);
                if (!c.has_boat() && c.boat_possible() && SolverModel._maybe_extra_boat_col(this.grid, j)) {
                    if (c.put_boat(false, true)) {
                        any = true;
                    }
                }
            }
            return any;
        }
        return false;
    }
}

export class BoatColStrategy extends ColumnStrategy {
    _apply_strategy(_values: ColComponent[], _water_left: number, _nothing_left: number): boolean {
        return false;
    }

    _apply(j: number): boolean {
        const full_hint = SolverModel._col_hint(this.grid, j);
        let hint = full_hint.boat_count;
        if (hint === -1) {
            if (full_hint.boat_count_type === E.HintType.Separated) {
                hint = 2;
            }
        }
        const boats_left_min = hint - this.grid.count_boat_col(j);
        if (boats_left_min <= 0) return false;
        const possible_boats = SolverModel._list_possible_boats_on_col(this.grid, j);
        if (possible_boats.length === boats_left_min) {
            let any = false;
            for (const lr of possible_boats) {
                if (SolverModel._put_boat_on_col(this.grid, lr, j)) {
                    any = true;
                }
            }
            return any;
        }
        return false;
    }
}

export class Section {
    start2: number;
    end2: number;
    single: boolean;

    constructor(b2: number) {
        this.start2 = b2;
        this.end2 = b2;
        this.single = true;
    }
}

export abstract class RowColStrategy extends Strategy {
    abstract _cell(a: number, b: number): CellWithLoc;
    abstract _left(): E.Side;
    abstract _right(): E.Side;
    abstract _a_len(): number;
    abstract _b_len(): number;
    abstract _a_hint(a: number): LineHint;
    abstract _count_water_a(a: number): number;

    _content(a: number, b2: number): Content {
        const c = this._cell(a, Math.floor(b2 / 2)).pure();
        return (b2 & 1) ? c._content_side(this._right()) : c._content_side(this._left());
    }

    _corner(a: number, b2: number): E.Corner {
        return E.diag_to_corner(this._cell(a, Math.floor(b2 / 2)).cell_type(), (b2 & 1) ? this._right() : this._left());
    }

    _wall_right(a: number, b2: number): boolean {
        if (b2 < 0) return true;
        const c = this._cell(a, Math.floor(b2 / 2));
        return (b2 & 1) ? c.wall_at(this._right() as unknown as E.Walls) : (c.cell_type() !== E.CellType.Single);
    }

    _will_flood_how_many(a: number, b2: number, invert_flood: boolean = false): number {
        if (this._content(a, b2) !== Content.Nothing) return 0;
        let b2_min = b2;
        let b2_max = b2;
        if (this._left() === E.Side.Left || !invert_flood) {
            while (!this._wall_right(a, b2_max) && this._content(a, b2_max + 1) === Content.Nothing) {
                b2_max += 1;
            }
        } else {
            if (!(b2_max & 1) && !this._wall_right(a, b2_max)) {
                b2_max += 1;
            }
        }
        if (this._left() === E.Side.Left || invert_flood) {
            while (b2_min > 0 && !this._wall_right(a, b2_min - 1) && this._content(a, b2_min - 1) === Content.Nothing) {
                b2_min -= 1;
            }
        } else {
            if ((b2_min & 1) && !this._wall_right(a, b2_min - 1)) {
                b2_min -= 1;
            }
        }
        return b2_max - b2_min + 1;
    }

    _empty_sections(a: number): Section[] {
        const ans: Section[] = [];
        for (let b2 = 0; b2 < 2 * this._b_len(); b2++) {
            if (this._content(a, b2) === Content.Nothing) {
                if (ans.length === 0 || this._wall_right(a, b2 - 1) || ans[ans.length - 1].end2 < b2 - 1) {
                    ans.push(new Section(b2));
                } else {
                    ans[ans.length - 1].end2 = b2;
                    if (this._left() !== E.Side.Left && !(b2 & 1)) {
                        ans[ans.length - 1].single = false;
                    }
                }
            }
        }
        return ans;
    }
}

export class TogetherStrategy extends RowColStrategy {
    basic: boolean;

    constructor(grid: GridImpl, basic_: boolean) {
        super(grid);
        this.basic = basic_;
    }

    _cell(a: number, b: number): CellWithLoc { throw new Error("Must implement"); }
    _left(): E.Side { throw new Error("Must implement"); }
    _right(): E.Side { throw new Error("Must implement"); }
    _a_len(): number { throw new Error("Must implement"); }
    _b_len(): number { throw new Error("Must implement"); }
    _a_hint(a: number): LineHint { throw new Error("Must implement"); }
    _count_water_a(a: number): number { throw new Error("Must implement"); }

    _basic_waters_and_nowaters(a: number): boolean {
        const h = this._a_hint(a).water_count;
        const b_len = this._b_len();
        let any = false;
        if (h * 2 > b_len) {
            const start = b_len - (Math.floor(2 * h) - b_len);
            const end = b_len + (Math.floor(2 * h) - b_len);
            for (let b2 = start; b2 < end; b2++) {
                if (this._content(a, b2) !== Content.Water) {
                    this._cell(a, Math.floor(b2 / 2)).put_water(this._corner(a, b2), false);
                    any = true;
                }
            }
        }
        return any;
    }

    _maybe_add_single_water(a: number): boolean {
        if (!this.basic) return false;
        let last_empty_b2 = -1;
        for (let b2 = 0; b2 < 2 * this._b_len(); b2++) {
            if (this._content(a, b2) === Content.Nothing || this._content(a, b2) === Content.NoBoat) {
                if (last_empty_b2 !== -1 && ((this._content(a, b2 - 1) !== Content.Nothing && this._content(a, b2 - 1) !== Content.NoBoat) || this._wall_right(a, b2 - 1))) {
                    return false;
                }
                last_empty_b2 = b2;
            }
        }
        if (last_empty_b2 !== -1) {
            this._cell(a, Math.floor(last_empty_b2 / 2)).put_water(this._corner(a, last_empty_b2), false);
            return true;
        }
        return false;
    }

    _add_necessary_waters_and_nowaters(a: number): boolean {
        const hint = Math.floor(2 * this._a_hint(a).water_count);
        if (hint <= 0) return this._maybe_add_single_water(a);
        if (this.basic) return this._basic_waters_and_nowaters(a);

        let any = false;
        let r2 = -1;
        let l2 = 0;
        let max_solution_right = -1;
        let min_solution_right = -1;
        let max_solution_left = -1;

        while (l2 < 2 * this._b_len()) {
            if (this._content(a, l2) !== Content.Nothing) {
                l2 += 1;
                continue;
            }
            if (r2 < l2) {
                r2 = l2 - 1;
            }
            while (r2 < 2 * this._b_len() - 1 && this._content(a, r2 + 1) === Content.Nothing && r2 - l2 + 1 < hint) {
                r2 += 1;
                while (r2 < l2 || (!this._wall_right(a, r2) && this._content(a, r2 + 1) === Content.Nothing)) {
                    r2 += 1;
                }
            }
            if (r2 - l2 + 1 === hint) {
                max_solution_right = r2;
                max_solution_left = l2;
                if (min_solution_right === -1) {
                    min_solution_right = r2;
                }
            }
            if (max_solution_right < l2) {
                any = true;
                this._cell(a, Math.floor(l2 / 2)).put_nowater(this._corner(a, l2), false, true);
            }
            if (this._left() === E.Side.Left) {
                while (!this._wall_right(a, l2)) {
                    l2 += 1;
                }
            } else {
                if (!(l2 & 1) && !this._wall_right(a, l2)) {
                    l2 += 1;
                }
            }
            l2 += 1;
        }

        for (let b2 = max_solution_left; b2 <= min_solution_right; b2++) {
            if (this._content(a, b2) === Content.Nothing) {
                this._cell(a, Math.floor(b2 / 2)).put_water(this._corner(a, b2), false);
                any = true;
            }
        }
        return any;
    }

    _apply(a: number): boolean {
        const a_hint = this._a_hint(a);
        if (a_hint.water_count_type !== E.HintType.Together) return false;
        let leftmost = 2 * this._b_len();
        let rightmost = -1;
        for (let b2 = 0; b2 < 2 * this._b_len(); b2++) {
            if (this._content(a, b2) === Content.Water) {
                leftmost = Math.min(leftmost, b2);
                rightmost = b2;
            }
        }
        if (rightmost === -1) {
            return this._add_necessary_waters_and_nowaters(a);
        }
        let any = false;
        if (this.basic) {
            for (let b2 = leftmost + 1; b2 < rightmost; b2++) {
                if (this._content(a, b2) !== Content.Water) {
                    any = true;
                    this._cell(a, Math.floor(b2 / 2)).put_water(this._corner(a, b2), false);
                }
            }
            if (any) return true;
        }

        let min_b2 = leftmost;
        while (min_b2 > 0 && this._content(a, min_b2 - 1) === Content.Nothing) {
            min_b2 -= 1;
        }
        let max_b2 = rightmost;
        while (max_b2 < 2 * this._b_len() - 1 && this._content(a, max_b2 + 1) === Content.Nothing) {
            max_b2 += 1;
        }

        const hint = a_hint.water_count;
        const water_left2 = Math.floor(2 * (hint - this._count_water_a(a)));
        if (water_left2 < 0) {
            if (hint >= 0) return false;
        }

        if (this.basic) {
            const no_b2: number[] = [];
            if (water_left2 >= 0) {
                for (let b2 = rightmost + water_left2 + 1; b2 <= max_b2; b2++) no_b2.push(b2);
                for (let b2 = leftmost - water_left2 - 1; b2 >= min_b2; b2--) no_b2.push(b2);
            }
            for (let b2 = 0; b2 < min_b2; b2++) no_b2.push(b2);
            for (let b2 = max_b2 + 1; b2 < 2 * this._b_len(); b2++) no_b2.push(b2);
            for (const b2 of no_b2) {
                if (this._content(a, b2) === Content.Nothing) {
                    any = true;
                    this._cell(a, Math.floor(b2 / 2)).put_nowater(this._corner(a, b2), false, true);
                }
            }
        } else {
            if (water_left2 < 0) return any;
            const yes_b2: number[] = [];
            if (leftmost - min_b2 < water_left2) {
                const limit = Math.min(rightmost + 1 + water_left2 - (leftmost - min_b2), 2 * this._b_len());
                for (let b2 = rightmost + 1; b2 < limit; b2++) yes_b2.push(b2);
            }
            if (max_b2 - rightmost < water_left2) {
                const start = Math.max(0, leftmost - (water_left2 - (max_b2 - rightmost)));
                for (let b2 = start; b2 < leftmost; b2++) yes_b2.push(b2);
            }
            for (const b2 of yes_b2) {
                if (this._content(a, b2) !== Content.Water) {
                    any = true;
                    this._cell(a, Math.floor(b2 / 2)).put_water(this._corner(a, b2), false);
                }
            }
        }
        return any;
    }

    apply_any(): boolean {
        let any = false;
        for (let a = 0; a < this._a_len(); a++) {
            if (this._apply(a)) any = true;
        }
        return any;
    }
}

export class TogetherRowStrategy extends TogetherStrategy {
    _cell(a: number, b: number): CellWithLoc { return this.grid.get_cell(a, b) as CellWithLoc; }
    _left(): E.Side { return E.Side.Left; }
    _right(): E.Side { return E.Side.Right; }
    _a_len(): number { return this.grid.rows(); }
    _b_len(): number { return this.grid.cols(); }
    _a_hint(a: number): LineHint { return SolverModel._row_hint(this.grid, a); }
    _count_water_a(a: number): number { return this.grid.count_water_row(a); }
}

export class TogetherColStrategy extends TogetherStrategy {
    _cell(a: number, b: number): CellWithLoc { return this.grid.get_cell(b, a) as CellWithLoc; }
    _left(): E.Side { return E.Side.Top; }
    _right(): E.Side { return E.Side.Bottom; }
    _a_len(): number { return this.grid.cols(); }
    _b_len(): number { return this.grid.rows(); }
    _a_hint(a: number): LineHint { return SolverModel._col_hint(this.grid, a); }
    _count_water_a(a: number): number { return this.grid.count_water_col(a); }
}

export enum TogetherStatus { None, AlwaysTogether, MaybeSeparated }

export class SeparateStrategy extends RowColStrategy {
    basic: boolean;

    constructor(grid: GridImpl, basic_: boolean) {
        super(grid);
        this.basic = basic_;
    }

    _cell(a: number, b: number): CellWithLoc { throw new Error("Must implement"); }
    _left(): E.Side { throw new Error("Must implement"); }
    _right(): E.Side { throw new Error("Must implement"); }
    _a_len(): number { throw new Error("Must implement"); }
    _b_len(): number { throw new Error("Must implement"); }
    _a_hint(a: number): LineHint { throw new Error("Must implement"); }
    _count_water_a(a: number): number { throw new Error("Must implement"); }

    _nothing(a: number, b2: number): boolean {
        const c = this._content(a, b2);
        return c === Content.Nothing || c === Content.NoBoat;
    }

    _water_or_nothing(a: number, b2: number): boolean {
        return this._content(a, b2) === Content.Water || this._nothing(a, b2);
    }

    _skip_right(a: number, b2: number, more_than_single: boolean): number {
        if (!(b2 & 1) && !this._wall_right(a, b2)) b2 += 1;
        while (more_than_single && !this._wall_right(a, b2)) b2 += 1;
        return b2 + 1;
    }

    _skip_left(a: number, b2: number, more_than_single: boolean): number {
        if ((b2 & 1) && !this._wall_right(a, b2 - 1)) b2 -= 1;
        while (more_than_single && b2 > 0 && !this._wall_right(a, b2 - 1)) b2 -= 1;
        return b2 - 1;
    }

    _will_be_together_right(a: number, b2: number): TogetherStatus {
        while (b2 < 2 * this._b_len() && !this._water_or_nothing(a, b2)) b2 += 1;
        if (b2 === 2 * this._b_len()) return TogetherStatus.None;
        if (this._content(a, b2) !== Content.Water) {
            b2 = this._skip_right(a, b2, true);
        }
        if (b2 === 2 * this._b_len()) return TogetherStatus.AlwaysTogether;
        while (b2 < 2 * this._b_len() && this._content(a, b2) === Content.Water) b2 += 1;
        if (b2 === 2 * this._b_len()) return TogetherStatus.AlwaysTogether;
        b2 = this._skip_right(a, b2, this._left() === E.Side.Left);
        while (b2 < 2 * this._b_len()) {
            if (this._water_or_nothing(a, b2)) return TogetherStatus.MaybeSeparated;
            b2 += 1;
        }
        return TogetherStatus.AlwaysTogether;
    }

    _will_be_together_left(a: number, b2: number): TogetherStatus {
        while (b2 >= 0 && !this._water_or_nothing(a, b2)) b2 -= 1;
        if (b2 < 0) return TogetherStatus.None;
        if (this._content(a, b2) !== Content.Water) {
            b2 = this._skip_left(a, b2, this._left() === E.Side.Left);
        }
        if (b2 < 0) return TogetherStatus.AlwaysTogether;
        while (b2 >= 0 && this._content(a, b2) === Content.Water) b2 -= 1;
        if (b2 < 0) return TogetherStatus.AlwaysTogether;
        b2 = this._skip_left(a, b2, true);
        while (b2 >= 0) {
            if (this._water_or_nothing(a, b2)) return TogetherStatus.MaybeSeparated;
            b2 -= 1;
        }
        return TogetherStatus.AlwaysTogether;
    }

    try_sections_strat(a: number): boolean {
        const sections = this._empty_sections(a);
        if (sections.length > 3 || sections.length === 0) return false;
        for (const section of sections) {
            if (this._nothing(a, section.start2) &&
                this._will_be_together_right(a, section.end2) === TogetherStatus.AlwaysTogether &&
                this._will_be_together_left(a, section.start2) === TogetherStatus.AlwaysTogether) {
                return this._cell(a, Math.floor(section.start2 / 2)).put_nowater(this._corner(a, section.start2), false, true);
            }
            if (this._nothing(a, section.end2)) {
                const r = this._will_be_together_right(a, section.end2 + 1);
                const l = this._will_be_together_left(a, section.start2 - 1);
                if ((r === TogetherStatus.AlwaysTogether && l === TogetherStatus.None) ||
                    (r === TogetherStatus.None && l === TogetherStatus.AlwaysTogether)) {
                    return this._cell(a, Math.floor(section.end2 / 2)).put_water(this._corner(a, section.end2), false) > 0;
                }
            }
        }
        return false;
    }

    _apply(a: number): boolean {
        const hint = this._a_hint(a);
        if (hint.water_count_type !== E.HintType.Separated) return false;
        if (!this.basic && this.try_sections_strat(a)) return true;
        if (hint.water_count_type !== E.HintType.Separated || hint.water_count === -1) return false;
        const water_left2 = Math.floor(2 * (hint.water_count - this._count_water_a(a)));
        if (water_left2 < 0) return false;
        let any = false;

        const BEFORE = 0, DURING = 1, AFTER = 2, SEPARATED = 3;

        if (!this.basic) {
            for (let b2 = 0; b2 < 2 * this._b_len(); b2++) {
                if (this._nothing(a, b2)) {
                    const b2_r = this._skip_right(a, b2, this._left() === E.Side.Left);
                    let state = BEFORE;
                    let left2 = Math.floor(2 * hint.water_count);
                    for (let c2 = b2_r; c2 < 2 * this._b_len(); c2++) {
                        if (this._water_or_nothing(a, c2)) {
                            if (state === BEFORE) state = DURING;
                            else if (state === AFTER) state = SEPARATED;
                            left2 -= 1;
                        } else if (state === DURING) {
                            state = AFTER;
                        }
                    }
                    if (state !== SEPARATED && left2 === 0) {
                        any = true;
                        this._cell(a, Math.floor(b2 / 2)).put_water(this._corner(a, b2), false);
                    }
                    break;
                } else if (this._content(a, b2) === Content.Water) {
                    break;
                }
            }
            for (let b2 = 2 * this._b_len() - 1; b2 >= 0; b2--) {
                if (this._nothing(a, b2)) {
                    const b2_l = this._skip_left(a, b2, true);
                    let state = BEFORE;
                    let left2 = Math.floor(2 * hint.water_count);
                    for (let c2 = b2_l; c2 >= 0; c2--) {
                        if (this._water_or_nothing(a, c2)) {
                            if (state === BEFORE) state = DURING;
                            else if (state === AFTER) state = SEPARATED;
                            left2 -= 1;
                        } else if (state === DURING) {
                            state = AFTER;
                        }
                    }
                    if (state !== SEPARATED && left2 === 0) {
                        any = true;
                        this._cell(a, Math.floor(b2 / 2)).put_water(this._corner(a, b2), false);
                    }
                    break;
                } else if (this._content(a, b2) === Content.Water) {
                    break;
                }
            }
        }

        let leftmost = 2 * this._b_len();
        let rightmost = -1;
        for (let b2 = 0; b2 < 2 * this._b_len(); b2++) {
            if (this._content(a, b2) === Content.Water) {
                leftmost = Math.min(leftmost, b2);
                rightmost = b2;
            }
        }
        if (rightmost === -1) {
            for (let b2 = 0; b2 < 2 * this._b_len(); b2++) {
                if (this._content(a, b2) === Content.Nothing) {
                    if (rightmost !== -1 && rightmost !== b2 - 1) {
                        leftmost = -1;
                    }
                    leftmost = Math.min(leftmost, b2);
                    rightmost = b2;
                    if (this.basic && this._will_flood_how_many(a, b2) === water_left2) {
                        this._cell(a, Math.floor(b2 / 2)).put_nowater(this._corner(a, b2), false, true);
                        any = true;
                    }
                }
            }
            return any;
        }
        if (!this.basic) return any;

        const not_water_middle = (rightmost - leftmost + 1) - Math.floor(2 * this._count_water_a(a));
        for (let b2 = leftmost + 1; b2 < rightmost; b2++) {
            const c = this._content(a, b2);
            if (c !== Content.Water) {
                if (not_water_middle === water_left2 && (c === Content.Nothing || c === Content.NoBoat) && this._will_flood_how_many(a, b2) === water_left2) {
                    this._cell(a, Math.floor(b2 / 2)).put_nowater(this._corner(a, b2), false, true);
                    return true;
                }
                return false;
            }
        }

        if (this._left() === E.Side.Top) {
            let b2 = leftmost - 1;
            while (b2 >= 0 && this._content(a, b2) === Content.Nothing) {
                if ((b2 & 1) && this._cell(a, Math.floor(b2 / 2)).cell_type() === E.CellType.Single) {
                    b2 -= 1;
                }
                if (leftmost - b2 === water_left2) {
                    this._cell(a, Math.floor(b2 / 2)).put_nowater(this._corner(a, b2), false, true);
                    any = true;
                    break;
                }
                if (leftmost - b2 > water_left2 || b2 === 0 || this._wall_right(a, b2 - 1)) {
                    break;
                } else {
                    b2 -= 1;
                }
            }
        } else {
            if (leftmost > 0 && (this._content(a, leftmost - 1) === Content.Nothing || this._content(a, leftmost - 1) === Content.NoBoat) && this._will_flood_how_many(a, leftmost - 1) === water_left2) {
                this._cell(a, Math.floor((leftmost - 1) / 2)).put_nowater(this._corner(a, leftmost - 1), false, true);
                any = true;
            }
        }
        if (rightmost < this._b_len() * 2 - 1 && this._content(a, rightmost + 1) === Content.Nothing && this._will_flood_how_many(a, rightmost + 1) === water_left2) {
            this._cell(a, Math.floor((rightmost + 1) / 2)).put_nowater(this._corner(a, rightmost + 1), false, true);
            any = true;
        }
        return any;
    }

    apply_any(): boolean {
        let any = false;
        for (let a = 0; a < this._a_len(); a++) {
            if (this._apply(a)) any = true;
        }
        return any;
    }
}

export class SeparateRowStrategy extends SeparateStrategy {
    _cell(a: number, b: number): CellWithLoc { return this.grid.get_cell(a, b) as CellWithLoc; }
    _left(): E.Side { return E.Side.Left; }
    _right(): E.Side { return E.Side.Right; }
    _a_len(): number { return this.grid.rows(); }
    _b_len(): number { return this.grid.cols(); }
    _a_hint(a: number): LineHint { return SolverModel._row_hint(this.grid, a); }
    _count_water_a(a: number): number { return this.grid.count_water_row(a); }
}

export class SeparateColStrategy extends SeparateStrategy {
    _cell(a: number, b: number): CellWithLoc { return this.grid.get_cell(b, a) as CellWithLoc; }
    _left(): E.Side { return E.Side.Top; }
    _right(): E.Side { return E.Side.Bottom; }
    _a_len(): number { return this.grid.cols(); }
    _b_len(): number { return this.grid.rows(); }
    _a_hint(a: number): LineHint { return SolverModel._col_hint(this.grid, a); }
    _count_water_a(a: number): number { return this.grid.count_water_col(a); }
}

export class AllWatersEasyStrategy extends Strategy {
    apply_any(): boolean {
        if (this.grid.grid_hints().total_water === -1.0) return false;
        const water_left = this.grid.grid_hints().total_water - this.grid.count_waters();
        if (water_left < 0) return false;
        let any = false;
        if (water_left === 0) {
            for (let i = 0; i < this.grid.rows(); i++) {
                for (let j = 0; j < this.grid.cols(); j++) {
                    const c = this.grid.get_cell(i, j);
                    for (const corner of c.corners()) {
                        if (c.nothing_at(corner)) {
                            if ((c as CellWithLoc).put_nowater(corner, false, true)) {
                                any = true;
                            }
                        }
                    }
                }
            }
            return any;
        }
        let count_nothing = 0.0;
        for (let i = 0; i < this.grid.rows(); i++) {
            for (let j = 0; j < this.grid.cols(); j++) {
                count_nothing += this.grid._pure_cell(i, j).nothing_count();
            }
        }
        if (water_left === count_nothing) {
            for (let i = 0; i < this.grid.rows(); i++) {
                for (let j = 0; j < this.grid.cols(); j++) {
                    const c = this.grid.get_cell(i, j);
                    for (const corner of c.corners()) {
                        if (c.nothing_at(corner)) {
                            if (c.put_water(corner, false) > 0) {
                                any = true;
                            }
                        }
                    }
                }
            }
        }
        return any;
    }
}

export class AllWatersMediumStrategy extends Strategy {
    apply_any(): boolean {
        if (this.grid.grid_hints().total_water === -1.0) return false;
        let water_left = this.grid.grid_hints().total_water - this.grid.count_waters();
        if (water_left <= 0) return false;
        let any = false;
        for (let i = 0; i < this.grid.rows(); i++) {
            for (let j = 0; j < this.grid.cols(); j++) {
                const c = this.grid.get_cell(i, j);
                for (const corner of c.corners()) {
                    if (!c.nothing_at(corner)) continue;
                    const test_opt = E.corner_is_left(corner) ? c.wall_at(E.Walls.Left) : (c.cell_type() !== E.CellType.Single);
                    if (test_opt) {
                        if (c.water_would_flood_how_many(corner) > water_left) {
                            if ((c as CellWithLoc).put_nowater(corner, false, true)) {
                                any = true;
                            }
                        }
                    }
                }
            }
        }
        water_left = this.grid.grid_hints().total_water - this.grid.count_waters();
        let count_nothing = 0.0;
        for (let i = 0; i < this.grid.rows(); i++) {
            for (let j = 0; j < this.grid.cols(); j++) {
                count_nothing += this.grid._pure_cell(i, j).nothing_count();
            }
        }
        if (water_left > count_nothing) return any;
        for (let i = 0; i < this.grid.rows(); i++) {
            for (let j = 0; j < this.grid.cols(); j++) {
                const c = this.grid.get_cell(i, j);
                for (const corner of c.corners()) {
                    if (!c.nothing_at(corner)) continue;
                    const test_opt = E.corner_is_left(corner) ? c.wall_at(E.Walls.Left) : (c.cell_type() !== E.CellType.Single);
                    if (test_opt) {
                        if (water_left > count_nothing - c.nowater_would_flood_how_many(corner)) {
                            if (c.put_water(corner, false) > 0) {
                                any = true;
                            }
                        }
                    }
                }
            }
        }
        return any;
    }
}

export class AllBoatsStrategy extends Strategy {
    apply_any(): boolean {
        const boats_left = this.grid.grid_hints().total_boats - this.grid.count_boats();
        if (boats_left <= 0) return false;
        const possible_boats: Vector2i[][] = [];
        let total_possible = 0;
        for (let j = 0; j < this.grid.cols(); j++) {
            if (!SolverModel._maybe_extra_boat_col(this.grid, j)) {
                possible_boats.push([]);
                continue;
            }
            const p = SolverModel._list_possible_boats_on_col(this.grid, j);
            total_possible += p.length;
            possible_boats.push(p);
        }
        let any = false;
        if (total_possible === boats_left) {
            for (let j = 0; j < this.grid.cols(); j++) {
                for (const lr of possible_boats[j]) {
                    if (SolverModel._put_boat_on_col(this.grid, lr, j)) {
                        any = true;
                    }
                }
            }
        }
        return any;
    }
}

export class AquariumsStrategy extends Strategy {
    basic: boolean;

    constructor(grid_: GridImpl, basic_: boolean) {
        super(grid_);
        this.basic = basic_;
    }

    _maybe_add_last_aquarium(hints: Record<number, number>, all_aqs: AquariumInfo[]): void {
        const water_left = this.grid.grid_hints().total_water - this.grid.count_waters();
        if (hints[0.0] === undefined || water_left <= 0 || hints[water_left] !== undefined) return;
        let non_fixed_0s = 0;
        for (const aq of all_aqs) {
            if (aq.total_water === 0 && !aq.fixed_water()) non_fixed_0s += 1;
            if (!aq.fixed_water() && aq.total_water > 0) return;
        }
        if (non_fixed_0s === hints[0.0] + 1) {
            hints[water_left] = 1;
        }
    }

    _infer_if_rest_is_0(hints: Record<number, number>, all_aqs: AquariumInfo[]): void {
        if (this.grid.grid_hints().total_water === -1) return;
        const fixed_aqs: Record<number, number> = {};
        let water_in_hints_and_fixed_aqs = 0.0;
        let biggest_aq = 0.0;
        for (const h in hints) {
            const val = parseFloat(h);
            water_in_hints_and_fixed_aqs += val * hints[val];
        }
        for (const aq of all_aqs) {
            biggest_aq = Math.max(biggest_aq, aq.total_empty + aq.total_water);
            if (aq.fixed_water() && hints[aq.total_water] === undefined) {
                fixed_aqs[aq.total_water] = (fixed_aqs[aq.total_water] || 0) + 1;
                water_in_hints_and_fixed_aqs += aq.total_water;
            }
        }
        if (this.grid.grid_hints().total_water !== water_in_hints_and_fixed_aqs) return;
        let filled_aqs_count = 0;
        while (biggest_aq > 0) {
            if (hints[biggest_aq] === undefined) {
                hints[biggest_aq] = fixed_aqs[biggest_aq] || 0;
            }
            filled_aqs_count += hints[biggest_aq];
            biggest_aq -= 0.5;
        }
        if (all_aqs.length >= filled_aqs_count) {
            hints[0.0] = all_aqs.length - filled_aqs_count;
        }
    }

    apply_any(): boolean {
        const hint: Record<number, number> = { ...this.grid.grid_hints().expected_aquariums };
        if (Object.keys(hint).length === 0) return false;
        const all_aqs: AquariumInfo[] = [];
        const dfs = new CrawlAquarium(this.grid);
        const last_seen = this.grid.last_seen;

        for (let i = this.grid.rows() - 1; i >= 0; i--) {
            for (let j = 0; j < this.grid.cols(); j++) {
                for (const corner of this.grid.get_cell(i, j).corners()) {
                    const c = this.grid._pure_cell(i, j);
                    if (c.last_seen(corner) < last_seen && !c.block_at(corner)) {
                        dfs.reset();
                        dfs.flood(i, j, corner);
                        dfs.reset_for_pool_check();
                        dfs.flood(i, j, corner);
                        all_aqs.push(dfs.info);
                    }
                }
            }
        }

        this._infer_if_rest_is_0(hint, all_aqs);
        const var_aqs: AquariumInfo[] = [];
        let any_pools = false;
        const ways_to_reach: Record<number, number> = {};

        for (const aq of all_aqs) {
            if (aq.fixed_water()) {
                if (hint[aq.total_water] !== undefined) {
                    hint[aq.total_water] -= 1;
                    if (hint[aq.total_water] < 0) return false;
                }
            } else {
                any_pools = any_pools || aq.has_pool;
                if (!aq.has_pool) {
                    var_aqs.push(aq);
                }
                if (any_pools) continue;
                let reaches = aq.total_water;
                ways_to_reach[reaches] = (ways_to_reach[reaches] || 0) + 1;
                for (const val of aq.empty_at_height) {
                    if (val === 0) continue;
                    reaches += val;
                    ways_to_reach[reaches] = (ways_to_reach[reaches] || 0) + 1;
                }
            }
        }

        this._maybe_add_last_aquarium(hint, all_aqs);
        let any = false;
        if (this.basic) {
            for (const aq of var_aqs) {
                let reaches = aq.total_water;
                for (let i = 0; i < aq.empty_at_height.length; i++) {
                    if (aq.empty_at_height[i] <= 0) continue;
                    if (hint[reaches] === 0) {
                        for (const pos of aq.cells_at_height[i]) {
                            SolverModel._put_water(this.grid, pos);
                        }
                        reaches += aq.empty_at_height[i];
                        any = true;
                    } else {
                        break;
                    }
                }
            }
        }
        if (any || this.basic) return any;

        for (const sz_str in hint) {
            const sz = parseFloat(sz_str);
            if (hint[sz] === 0 || hint[sz] !== (ways_to_reach[sz] || 0) || any_pools) continue;
            for (const aq of var_aqs) {
                let reaches = aq.total_water;
                for (let i = 0; i < aq.empty_at_height.length; i++) {
                    if (aq.empty_at_height[i] <= 0) continue;
                    else if (reaches === sz) {
                        for (const pos of aq.cells_at_height[i]) {
                            SolverModel._put_nowater(this.grid, pos);
                        }
                        any = true;
                    } else {
                        reaches += aq.empty_at_height[i];
                        if (reaches === sz) {
                            for (const pos of aq.cells_at_height[i]) {
                                SolverModel._put_water(this.grid, pos);
                            }
                            any = true;
                        }
                    }
                }
            }
        }
        if (any) return true;

        for (const aq of var_aqs) {
            let reaches = aq.total_water + aq.total_empty;
            for (let i = aq.empty_at_height.length - 1; i >= 0; i--) {
                if (aq.empty_at_height[i] <= 0) continue;
                if (hint[reaches] === 0) {
                    for (const pos of aq.cells_at_height[i]) {
                        SolverModel._put_nowater(this.grid, pos);
                    }
                    reaches -= aq.empty_at_height[i];
                    any = true;
                } else {
                    break;
                }
            }
        }
        return any;
    }
}

export abstract class CellHintsStrategy extends Strategy {
    apply_any(): boolean {
        let any = false;
        for (let i = 0; i < this.grid.rows(); i++) {
            for (let j = 0; j < this.grid.cols(); j++) {
                const c = this.grid.get_cell(i, j).hints();
                if (c !== null && this._apply(i, j, c)) {
                    any = true;
                }
            }
        }
        return any;
    }
    abstract _apply(i: number, j: number, hint: CellHints): boolean;
}

export class CellHintsBasic extends CellHintsStrategy {
    _apply(i: number, j: number, hint: CellHints): boolean {
        if (hint.adj_water_count < 0) return false;
        const nothing_adj = this.grid.count_nothing_adj(i, j);
        if (nothing_adj === 0) return false;
        const water_adj = this.grid.count_water_adj(i, j);
        let fill_with: Content;
        if (water_adj === hint.adj_water_count) {
            fill_with = Content.NoWater;
        } else if (water_adj + nothing_adj === hint.adj_water_count) {
            fill_with = Content.Water;
        } else {
            return false;
        }
        let any = false;
        for (const di of [-1, 0, 1]) {
            for (const dj of [-1, 0, 1]) {
                if (i + di >= 0 && i + di < this.grid.rows() && j + dj >= 0 && j + dj < this.grid.cols()) {
                    const c = this.grid.get_cell(i + di, j + dj);
                    for (const corner of c.corners()) {
                        const cont = c.pure()._content_at(corner);
                        if (cont === Content.Nothing || cont === Content.NoBoat) {
                            if (fill_with === Content.Water) {
                                if (c.put_water(corner, false) > 0) any = true;
                            } else {
                                if ((c as CellWithLoc).put_nowater(corner, false, true)) any = true;
                            }
                        }
                    }
                }
            }
        }
        return any;
    }
}

export class CellHintsMore extends CellHintsStrategy {
    advanced: boolean;

    constructor(grid_: GridImpl, advanced_: boolean) {
        super(grid_);
        this.advanced = advanced_;
    }

    _apply(i: number, j: number, hint: CellHints): boolean {
        if (hint.adj_water_count < 0.0 || this.grid.count_nothing_adj(i, j) === 0) return false;
        return SolverModel.generic_solve(this.grid, this.advanced, hint.adj_water_count, new RectAreaCheck(new Rect2i(i - 1, j - 1, 3, 3)));
    }
}

export class RectWithExclusionArea implements AreaCheck {
    include_rect: Rect2i;
    exclude_rect: Rect2i;

    constructor(inc: Rect2i, exc: Rect2i) {
        this.include_rect = inc;
        this.exclude_rect = exc;
    }

    inside(i: number, j: number): boolean {
        const v = new Vector2i(i, j);
        return this.include_rect.has_point(v) && !this.exclude_rect.has_point(v);
    }

    all_points(): Vector2i[] {
        return new RectAreaCheck(this.include_rect).all_points().filter(v => !this.exclude_rect.has_point(v));
    }
}

export class TwoCellHints extends Strategy {
    advanced: boolean;

    constructor(grid_: GridImpl, advanced_: boolean) {
        super(grid_);
        this.advanced = advanced_;
    }

    _fixed_water_outside_intersection(i: number, j: number, di: number, dj: number): number {
        const rect1 = new Rect2i(0, 0, this.grid.rows(), this.grid.cols());
        const rect2 = new Rect2i(i + di - 1, j + dj - 1, 3, 3);
        let tot = 0.0;
        for (const di2 of [-1, 0, 1]) {
            for (const dj2 of [-1, 0, 1]) {
                const v = new Vector2i(i + di2, j + dj2);
                if (rect1.has_point(v) && !rect2.has_point(v)) {
                    const c = this.grid._pure_cell(i + di2, j + dj2);
                    tot += c.water_count();
                    if (c.nothing_count() > 0) return -1.0;
                }
            }
        }
        return tot;
    }

    apply_any(): boolean {
        let any = false;
        const rect = new Rect2i(0, 0, this.grid.rows(), this.grid.cols());
        for (let i = 0; i < this.grid.rows(); i++) {
            for (let j = 0; j < this.grid.cols(); j++) {
                const c = this.grid.get_cell(i, j).hints();
                if (c === null || c.adj_water_count <= 0.0) continue;
                for (let di = -2; di <= 2; di++) {
                    for (let dj = -2; dj <= 2; dj++) {
                        if ((di === 0 && dj === 0) || !rect.has_point(new Vector2i(i + di, j + dj))) continue;
                        const d = this.grid.get_cell(i + di, j + dj).hints();
                        if (d === null || d.adj_water_count <= 0.0) continue;
                        const extra = this._fixed_water_outside_intersection(i, j, di, dj);
                        if (extra === -1) continue;
                        if (SolverModel.generic_solve(
                            this.grid,
                            this.advanced,
                            d.adj_water_count - (c.adj_water_count - extra),
                            new RectWithExclusionArea(new Rect2i(i + di - 1, j + dj - 1, 3, 3), new Rect2i(i - 1, j - 1, 3, 3))
                        )) {
                            any = true;
                        }
                    }
                }
            }
        }
        return any;
    }
}

export class ComponentAdjDfs extends BaseAdjDfs {
    constructor(grid_: GridImpl, ci: number, cj: number) {
        super(grid_, ci, cj);
        this.calc_component_info();
    }

    _is_content_ok(c: Content): boolean {
        return c === Content.Nothing || c === Content.NoBoat || c === Content.Water;
    }
}

export class CellHintTogetherToDo {
    to_mark_nowater: WaterPosition[] = [];
    impossible: boolean = false;

    get_fill_result(grid: GridImpl, fill_area: AreaCheck, rect: Rect2i, pos: Vector2i): Record<string, boolean> {
        if (pos.y < 0 || !grid.inside(pos.x, Math.floor(pos.y / 2))) return {};
        const cont = Ij2.content(grid, pos);
        if (cont === Content.Water) {
            return { [`${pos.x},${pos.y}`]: true };
        } else if (cont !== Content.Nothing && cont !== Content.NoBoat) {
            return {};
        }
        const all_filled = grid.get_cell(pos.x, Math.floor(pos.y / 2)).water_would_flood_which(Ij2.corner(grid, pos), fill_area);
        const ret: Record<string, boolean> = {};
        for (const filled of all_filled) {
            if (rect.has_point(new Vector2i(filled.i, filled.j))) {
                const ij2 = filled.to_ij2();
                ret[`${ij2.x},${ij2.y}`] = true;
            }
        }
        return ret;
    }

    get_fill_cost(grid: GridImpl, result: Vector2i[]): number {
        if (result.length === 0) return 0.0;
        if (Ij2.content(grid, result[0]) === Content.Water) return 0.0;
        let tot = 0.0;
        for (const filled of result) {
            tot += Ij2.size(grid, filled);
        }
        return tot;
    }

    mark_far_away_nowaters(grid: GridImpl, ci: number, cj: number, waters_left: number): void {
        const start_positions: Vector2i[] = [];
        const wdfs = new WaterAdjDfs(grid, ci, cj);
        for (let i = ci - 1; i <= ci + 1; i++) {
            for (let j2 = 2 * cj - 2; j2 <= 2 * cj + 3; j2++) {
                if (wdfs.flood(i, j2)) {
                    start_positions.push(new Vector2i(i, j2));
                }
            }
        }
        const fill_area = new RectAreaCheck(new Rect2i(ci - 1, 0, 3, grid.cols()));
        const rect_area = new Rect2i(ci - 1, cj - 1, 3, 3);
        const visited_any: Record<string, boolean> = {};

        for (const spos of start_positions) {
            const visited: Record<string, boolean> = {};
            const dist_2_pos = new Map<number, Vector2i[]>();
            const pos_2_filled = new Map<string, Record<string, boolean>>();
            let cur_dist = 0.0;
            let total_new_water_visited = 0.0;
            dist_2_pos.set(cur_dist, [spos]);

            while (dist_2_pos.size > 0) {
                const cur_pos = dist_2_pos.get(cur_dist) || [];
                dist_2_pos.delete(cur_dist);
                while (cur_pos.length > 0) {
                    const pos = cur_pos.pop()!;
                    const key = `${pos.x},${pos.y}`;
                    if (visited[key]) continue;
                    visited[key] = true;
                    visited_any[key] = true;
                    if (Ij2.content(grid, pos) === Content.Nothing || Ij2.content(grid, pos) === Content.NoBoat) {
                        total_new_water_visited += Ij2.size(grid, pos);
                    }
                    for (const adj of BaseAdjDfs.all_adj(grid, pos, true)) {
                        const adj_key = `${adj.x},${adj.y}`;
                        const filled_d = this.get_fill_result(grid, fill_area, rect_area, adj);
                        pos_2_filled.set(adj_key, filled_d);
                        const filled: Vector2i[] = [];
                        const prev_filled = pos_2_filled.get(key) || {};
                        for (const npos_str of Object.keys(filled_d)) {
                            if (!prev_filled[npos_str]) {
                                const [nx, ny] = npos_str.split(',').map(Number);
                                filled.push(new Vector2i(nx, ny));
                            }
                        }
                        const cost = this.get_fill_cost(grid, filled);
                        if (cur_dist + cost > waters_left) continue;
                        for (const npos of filled) {
                            if (cost === 0) {
                                cur_pos.push(npos);
                            } else {
                                const d = cur_dist + cost;
                                if (!dist_2_pos.has(d)) dist_2_pos.set(d, []);
                                dist_2_pos.get(d)!.push(npos);
                            }
                        }
                    }
                }
                cur_dist += 0.5;
            }
            if (total_new_water_visited < waters_left) {
                this.impossible = true;
            }
            for (const other_spos of start_positions) {
                if (!visited[`${other_spos.x},${other_spos.y}`]) {
                    this.impossible = true;
                }
            }
        }
        for (let i = ci - 1; i <= ci + 1; i++) {
            for (let j = cj - 1; j <= cj + 1; j++) {
                if (!grid.inside(i, j)) continue;
                const c = grid._pure_cell(i, j);
                for (const loc of c.waters()) {
                    const wpos = new WaterPosition(i, j, loc);
                    const ij2 = wpos.to_ij2();
                    if (visited_any[`${ij2.x},${ij2.y}`]) continue;
                    const cont = c._content_at(E.waters_to_corner(loc));
                    if (cont === Content.Nothing || cont === Content.NoBoat) {
                        this.to_mark_nowater.push(wpos);
                    }
                }
            }
        }
    }

    static create(grid: GridImpl, ci: number, cj: number, expected_together_waters: number): CellHintTogetherToDo {
        const todo = new CellHintTogetherToDo();
        const dfs = new ComponentAdjDfs(grid, ci, cj);
        const empty_cmps: ComponentInfo[] = [];
        let any_water = false;
        let waters_left = expected_together_waters;

        for (let i = ci - 1; i <= ci + 1; i++) {
            for (let j2 = 2 * cj - 2; j2 <= 2 * cj + 3; j2++) {
                if (dfs.flood(i, j2)) {
                    if (dfs.info.total_water > 0) {
                        waters_left -= dfs.info.total_water;
                        if (any_water) {
                            todo.impossible = true;
                        }
                        if (expected_together_waters >= 0 && dfs.info.total_water + dfs.info.total_empty < expected_together_waters) {
                            todo.impossible = true;
                        }
                        any_water = true;
                    } else if (dfs.info.total_empty > 0) {
                        if (expected_together_waters > dfs.info.total_empty) {
                            todo.to_mark_nowater.push(...dfs.info.empties);
                        } else {
                            empty_cmps.push(dfs.info);
                        }
                    }
                }
            }
        }
        if (any_water) {
            for (const cmp of empty_cmps) {
                todo.to_mark_nowater.push(...cmp.empties);
            }
            if (waters_left > 0) {
                todo.mark_far_away_nowaters(grid, ci, cj, waters_left);
            }
        } else if (empty_cmps.length === 0) {
            todo.impossible = true;
        }
        return todo;
    }
}

export class BasicTogetherCellHintsStrategy extends CellHintsStrategy {
    _apply(ci: number, cj: number, hint: CellHints): boolean {
        if (hint.adj_water_count_type !== E.HintType.Together) return false;
        const todo = CellHintTogetherToDo.create(this.grid, ci, cj, hint.adj_water_count);
        if (todo.impossible) return false;
        let any = false;
        for (const pos of todo.to_mark_nowater) {
            if (SolverModel._put_nowater(this.grid, pos)) {
                any = true;
            }
        }
        return any;
    }
}

export class PropagateAdjacentEmptiesDfs extends Dfs {
    _cell_logic(_i: number, _j: number, corner: E.Corner, cell: PureCell): boolean {
        const content = cell._content_at(corner);
        return content === Content.Nothing || content === Content.NoBoat;
    }
    _can_go_up(_i: number, _j: number): boolean { return true; }
    _can_go_down(_i: number, _j: number): boolean { return false; }
}

export class TogetherSeparateCellHintsStrategy extends CellHintsStrategy {
    hint_now_invalid(ci: number, cj: number, hint: CellHints): boolean {
        if (hint.adj_water_count_type === E.HintType.Separated) {
            return SolverModel.is_cellhint_separated_impossible(this.grid, ci, cj, hint);
        }
        if (hint.adj_water_count_type === E.HintType.Together) {
            return CellHintTogetherToDo.create(this.grid, ci, cj, hint.adj_water_count).impossible;
        }
        return false;
    }

    try_water_nowater(ci: number, cj: number, hint: CellHints, i: number, j: number, waters: E.Waters): boolean {
        const c = this.grid.get_cell(i, j);
        const corner = E.waters_to_corner(waters);
        const content = this.grid._pure_cell(i, j)._content_at(corner);
        if (content === Content.Nothing || content === Content.NoBoat) {
            c.put_water(corner, true);
            if (this.hint_now_invalid(ci, cj, hint)) {
                this.grid.undo();
                SolverModel._put_nowater(this.grid, new WaterPosition(i, j, waters));
                return true;
            }
            this.grid.undo();
            (c as CellWithLoc).put_nowater(corner, true, true);
            if (this.hint_now_invalid(ci, cj, hint)) {
                this.grid.undo();
                SolverModel._put_water(this.grid, new WaterPosition(i, j, waters));
                return true;
            }
            this.grid.undo();
        }
        return false;
    }

    _apply(ci: number, cj: number, hint: CellHints): boolean {
        if (hint.adj_water_count_type === E.HintType.Hidden || hint.adj_water_count_type === E.HintType.Zero) {
            return false;
        }
        let any = false;
        for (let i = ci - 1; i <= ci + 1; i++) {
            for (let j = cj - 1; j <= cj + 1; j++) {
                if (!this.grid.inside(i, j)) continue;
                const c = this.grid.get_cell(i, j);
                const waters = c.waters();
                if (j === cj - 1 || this.grid.wall_at(i, j, E.Side.Left)) {
                    if (this.try_water_nowater(ci, cj, hint, i, j, waters[0])) {
                        any = true;
                    }
                }
                if (waters.length > 1) {
                    if (this.try_water_nowater(ci, cj, hint, i, j, waters[1])) {
                        any = true;
                    }
                }
            }
        }
        return any;
    }
}
