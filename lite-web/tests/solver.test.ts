import { describe, test, expect } from 'vitest';
import { E } from '../src/engine/E';
import { GridImpl } from '../src/engine/GridImpl';
import { LoadMode } from '../src/engine/Grid';
import { SolverModel } from '../src/engine/Solver';
import { OptionsSum } from '../src/engine/SubsetSum';

function cleanGridStr(s: string): string {
    const lines = s.replace(/\r/g, '').split('\n');
    while (lines.length > 0 && lines[0].trim() === '') lines.shift();
    while (lines.length > 0 && lines[lines.length - 1].trim() === '') lines.pop();
    if (lines.length === 0) return '';
    const indents = lines.filter(l => l.length > 0).map(l => l.match(/^(\s*)/)![1].length);
    const minIndent = Math.min(...indents);
    return lines.map(l => l.slice(minIndent).trimEnd()).join('\n');
}

function assert_grid_eq(a: string, b: string): void {
    expect(cleanGridStr(a)).toBe(cleanGridStr(b));
}

function str_grid(s: string): GridImpl {
    const g = GridImpl.from_str(s, LoadMode.Testing);
    const g2 = GridImpl.import_data(g.export_data(), LoadMode.Testing);
    expect(g.equal(g2)).toBe(true);
    return g;
}

function apply_strategies(s: string, strategies: string[] = []): GridImpl {
    const g = str_grid(s);
    expect(g.are_hints_satisfied(true)).toBe(false);
    if (strategies.length === 0) {
        strategies = Object.keys(SolverModel.STRATEGY_LIST);
    }
    new SolverModel().apply_strategies(g, strategies);
    return g;
}

function assert_can_solve(s: string, strategies: string[] = [], result: boolean = true): void {
    const g = apply_strategies(s, strategies);
    if (g.are_hints_satisfied(true) !== result) {
        if (result) {
            console.error("Not solved:\n" + g.to_str());
        } else {
            console.error("Solved but shouldn't:\n" + g.to_str());
        }
    }
    expect(g.are_hints_satisfied(true)).toBe(result);
}

function assert_cant_solve(s: string, strategies: string[] = []): void {
    assert_can_solve(s, strategies, false);
}

function assert_apply_strategies(s: string, res: string = "", strategies: string[] = []): void {
    if (res === "") {
        res = s.replace(/W/g, "w").replace(/X/g, "x");
        s = s.replace(/W/g, ".").replace(/X/g, ".");
    }
    assert_grid_eq(apply_strategies(s, strategies).to_str(), res);
}

describe('SolverTests ported from Godot GridTests.gd', () => {
    test('test_simple_solve', () => {
        const g = str_grid(`
	h..1.3.
	2......
	.|╲_/./
	2......
	.L._.L.
`);
        expect(g.are_hints_satisfied()).toBe(false);
        expect(g.col_hints()[0].water_count).toBe(-1.0);
        expect(g.col_hints()[1].water_count).toBe(0.5);
        expect(g.col_hints()[2].water_count).toBe(1.5);
        expect(g.row_hints()[0].water_count).toBe(1.0);
        expect(g.row_hints()[1].water_count).toBe(1.0);
        g.get_cell(0, 1).put_water(E.Corner.BottomRight);
        g.get_cell(1, 2).put_water(E.Corner.BottomLeft);
        // Successfully solved, hooray!
        expect(g.are_hints_satisfied()).toBe(true);
        g.undo();
        g.undo();
        expect(g.are_hints_satisfied()).toBe(false);
        new SolverModel().apply_strategies(g, Object.keys(SolverModel.STRATEGY_LIST));
        assert_grid_eq(g.to_str(), `
	h..1.3.
	2xxxwwx
	.|╲_/./
	2xxxxww
	.L._.L.
`);
    });

    test('test_solver_rows', () => {
        const solver = new SolverModel();
        const g = str_grid(`
	h....
	2....
	.L.|.
	3....
	.L._╲
`);
        solver.apply_strategies(g, Object.keys(SolverModel.STRATEGY_LIST));
        assert_grid_eq(g.to_str(), `
	h....
	2wwxx
	.L.|.
	3wwwx
	.L._╲
`);
        solver.apply_strategies(str_grid(`
	h....
	2.ww.
	.|╲./
	.....
	.L._.
`), Object.keys(SolverModel.STRATEGY_LIST));
    });

    test('test_options_sum', () => {
        expect(OptionsSum.can_be_solved(10.0, [[1.0, 9.0], [2.0, 9.0]])).toBe(true);
        expect(OptionsSum.can_be_solved(3.0, [[1.0, 9.0], [2.0, 9.0]])).toBe(true);
        expect(OptionsSum.can_be_solved(11.0, [[1.0, 9.0], [2.0, 9.0]])).toBe(true);
        expect(OptionsSum.can_be_solved(18.0, [[1.0, 9.0], [2.0, 9.0]])).toBe(true);
        expect(OptionsSum.can_be_solved(2.0, [[1.0, 9.0], [2.0, 9.0]])).toBe(false);
        expect(OptionsSum.can_be_solved(12.0, [[1.0, 9.0], [2.0, 9.0]])).toBe(false);
        expect(OptionsSum.can_be_solved(4.0, [[1.0, 9.0], [2.0, 9.0]])).toBe(false);
        expect(OptionsSum.can_be_solved(0.0, [[1.0, 9.0], [2.0, 9.0]])).toBe(false);
        expect(OptionsSum.can_be_solved(2.0, [[0.0], [0.0, 1.0], [0.0, 1.0]])).toBe(true);
    });

    test('test_subset_sum', () => {
        assert_can_solve(`
	h........2.
	2..........
	.L._._.|.L.
	6..........
	.L._.L._.L.
	`);
    });

    test('test_can_solve', () => {
        assert_can_solve("h2.\n...\n...");
        assert_can_solve(`
	h4...
	2....
	._.L.
	2....
	...|.
	2....
	._.L.
	`);
        assert_can_solve("h2.\n...\n...\n...\n...\n...\n...");
        assert_can_solve(`
	+boats=1
	B...
	.h..
	1...
	....
	....
	....
	`);
        assert_can_solve(`
	+boats=1
	B.1.
	.h..
	....
	....
	....
	....
	`);
        const col_with_halfcell = (s: string) => `
	h3.
	.${s}.
	../
	...
	.L.
	...
	.L.
	`;
        assert_can_solve(col_with_halfcell("#"));
        assert_cant_solve(col_with_halfcell("."));
        // Can't guess water level
        assert_cant_solve(`
	+boats=1
	B.1.
	.h..
	....
	....
	....
	....
	....
	....
	`);
        // Can guess the left boat but not the right unless it's X on top
        const grid_with_2_boats = (a: string, b: string, c: string) => `
	+boats=2
	##${a}
	L.|.
	${b}
	|.|.
	${c}
	L.L.
	`;
        assert_grid_eq(apply_strategies(grid_with_2_boats("..", "....", "....")).to_str(), grid_with_2_boats("xx", "bb..", "wwww"));
        assert_grid_eq(apply_strategies(grid_with_2_boats("..", "..xx", "....")).to_str(), grid_with_2_boats("xx", "bbbb", "wwww"));
        assert_cant_solve(`
	+boats=1
	B1.
	.xx
	.|.
	...
	.|.
	.ww
	.L.
	`);
        assert_cant_solve(`
	+boats=1
	xx
	|.
	..
	|.
	ww
	L.
	`);
        const grid_with_1_boat_col = (h: string, a: string, b: string, c: string) => `
	+boats=1
	B${h}.
	.${a}
	.|.
	.${b}
	.|.
	0${c}
	.L.
	`;
        for (const s of ["BoatCol", "AllBoats"]) {
            const h = s === "BoatCol" ? "1" : ".";
            assert_can_solve(grid_with_1_boat_col(h, "..", "ww", "ww"), [s]);
            assert_can_solve(grid_with_1_boat_col(h, "xx", "xx", "ww"), [s]);
            assert_can_solve(grid_with_1_boat_col(h, "xx", "xx", ".."), [s]);
            assert_grid_eq(apply_strategies(grid_with_1_boat_col(h, "..", "..", ".."), [s]).to_str(), grid_with_1_boat_col(h, "xx", "..", "ww"));
            assert_grid_eq(apply_strategies(grid_with_1_boat_col(h, "xx", "..", ".."), [s]).to_str(), grid_with_1_boat_col(h, "xx", "..", "ww"));
            assert_grid_eq(apply_strategies(grid_with_1_boat_col(h, "..", "..", "ww"), [s]).to_str(), grid_with_1_boat_col(h, "xx", "..", "ww"));
        }
        // Using cross row-col boat elimination
        const grid_two_boats = (boats: number, a: string) => `
	+boats=${boats}
	B..0...
	${a}......
	.|.....
	.wwwwww
	.L._._.
	`;
        assert_can_solve(grid_two_boats(-1, "2"), ["BoatRow"]);
        assert_can_solve(grid_two_boats(2, "."), ["AllBoats"]);
        assert_cant_solve(grid_two_boats(-1, "."));
        assert_can_solve(`
	+boats=-1
	B1.
	.xx
	.|.
	.ww
	.L.
	0xx
	.|.
	.ww
	.L.
	`);
        const grid_row_1_boat = (a: string, b: string) => `
	+boats=-1
	B1.
	${a}xx
	.|.
	${b}..
	.|.
	.ww
	.L.
	`;
        assert_can_solve(grid_row_1_boat(".", "0"));
        assert_can_solve(grid_row_1_boat("0", "."));
        assert_cant_solve(grid_row_1_boat(".", "."));
    });

    test('test_guess_boat', () => {
        const g = str_grid(`
	+boats=1
	B....
	1....
	.|...
	.....
	.L._.
	`);
        new SolverModel().full_solve(g, Object.keys(SolverModel.STRATEGY_LIST), () => false);
        expect(g.are_hints_satisfied()).toBe(true);
    });

    test('test_together_rules', () => {
        let g = str_grid(`
	h......
	4......
	}L.L.L.
	`);
        g.get_cell(0, 0).put_water(E.Corner.TopRight);
        g.get_cell(0, 2).put_water(E.Corner.TopRight);
        expect(g.are_hints_satisfied()).toBe(false);
        g.get_cell(0, 2).remove_content(E.Corner.TopRight);
        g.get_cell(0, 1).put_water(E.Corner.TopRight);
        expect(g.are_hints_satisfied()).toBe(true);
        // Same but vertical
        g = str_grid(`
	h4}
	...
	.L.
	...
	.L.
	...
	.L.
	`);
        g.get_cell(0, 0).put_water(E.Corner.TopRight);
        g.get_cell(2, 0).put_water(E.Corner.TopRight);
        expect(g.are_hints_satisfied()).toBe(false);
        g.get_cell(2, 0).remove_content(E.Corner.TopRight);
        g.get_cell(1, 0).put_water(E.Corner.TopRight);
        expect(g.are_hints_satisfied()).toBe(true);
        assert_can_solve(`
	h....
	.wwx.
	}L.L/
	`, ["TogetherRowBasic"]);
        assert_can_solve(`
	h........
	5....w...
	}L/L.L/_.
	`);
    });

    test('test_solve_together', () => {
        let s = ["TogetherRowBasic", "TogetherRowAdvanced"];
        assert_can_solve(`
	h....
	3w.w.
	}L/L/
	`, s);
        assert_grid_eq(apply_strategies(`
	h....
	2.w..
	}L/L/
	`, s).to_str(), `
	h....
	2.w.x
	}L/L/
	`);
        assert_grid_eq(apply_strategies(`
	h....
	3.w..
	}L/L/
	`, s).to_str(), `
	h....
	3.ww.
	}L/L/
	`);
        assert_can_solve(`
	h....
	2.x..
	}L/L/
	`, ["TogetherRowAdvanced", "BasicRow"]);
        // empty hole but not too big
        assert_grid_eq(apply_strategies(`
	h......
	3.x....
	}L/L/L/
	`, s).to_str(), `
	h......
	3xx.ww.
	}L/L/L/
	`);
        assert_grid_eq(apply_strategies(`
	h........
	2....x...
	}L/_/L/_/
	`).to_str(), `
	h........
	2x..xx..x
	}L/_/L/_/
	`);
        // Same but for columns
        s = ["TogetherColBasic", "TogetherColAdvanced"];
        assert_can_solve(`
	h3}
	.w.
	.L/
	.w.
	.L/
	`, s);
        assert_grid_eq(apply_strategies(`
	h2}
	..w
	.L/
	...
	.L/
	`, s).to_str(), `
	h2}
	..w
	.L/
	..x
	.L/
	`);
        assert_grid_eq(apply_strategies(`
	h3}
	..w
	.L/
	...
	.L/
	`, s).to_str(), `
	h3}
	..w
	.L/
	.w.
	.L/
	`);
    });

    test('test_wrong_rule', () => {
        assert_can_solve(`
	h1...
	3w...
	-L/L.
	`);
    });

    test('test_separate_rule', () => {
        let s = ["BasicRow", "SeparateRowBasic", "SeparateRowAdvanced"];
        // Disregard aquarium of size 2
        assert_can_solve(`
	h....
	2....
	-L/_/
	`, s);
        // Put nowater in nearby aquariums because it would be together
        assert_can_solve(`
	h........
	3..w....#
	-L.L/_/_/
	`, s);
        // Can't fill middle or it would be together
        assert_can_solve(`
	h....
	3.w.w
	-L/L/
	`, s);
        assert_can_solve(`
	h......
	4......
	-L.L.L/
	`, s);
        // 3 blocks, must put air in middle
        assert_can_solve(`
	h........
	.........
	-L.L._.L.
	`, s);
        // Must put air and water
        assert_can_solve(`
	h......
	.ww....
	-L.L.L.
	`, s);
        assert_cant_solve(`
	h......
	3#.w.xw
	-L/L/L/
	`, s);
        assert_apply_strategies(`
	h......
	5......
	-L/L/L/
	`, `
	h......
	5w....w
	-L/L/L/
	`, s);
        assert_apply_strategies(`
	h......
	5..w...
	-L/L/L/
	`, `
	h......
	5w.w..w
	-L/L/L/
	`, s);
        s = ["BasicCol", "SeparateColBasic", "SeparateColAdvanced"];
        assert_can_solve(`
	h2-
	...
	.|/
	..#
	.L/
	`, s);
        // Must mark (0, 1) as X
        assert_can_solve(`
	h6-
	...
	.L.
	...
	.|.
	...
	.|.
	.ww
	.L.
	`, s);
        const single_block = "...\n.L.";
        const water_block = ".ww\n.L.";
        const double_block = "...\n.|.\n" + single_block;
        const three_blocks = (b1: string, b2: string, b3: string) => `h.-\n${b1}\n${b2}\n${b3}`;
        assert_can_solve(three_blocks(single_block, single_block, single_block), s);
        assert_apply_strategies(three_blocks(double_block, single_block, single_block), three_blocks("...\n.|.\n" + water_block, ".xx\n.L.", water_block), s);
        assert_cant_solve(three_blocks(single_block, double_block, single_block), s);
        assert_cant_solve(three_blocks(single_block, single_block, double_block), s);
        assert_can_solve(three_blocks(single_block, double_block, ""), s);
        assert_can_solve(three_blocks(water_block, single_block, single_block), s);
        assert_cant_solve(three_blocks(water_block, single_block, double_block), s);
        assert_can_solve(three_blocks(water_block, double_block, ""), s);
    });

    test('test_total_waters', () => {
        let s = ["AllWatersEasy"];
        assert_can_solve(`
	+waters=1
	..
	L.
	`, s);
        assert_can_solve(`
	+waters=1
	..ww
	L.L.
	`, s);
        s = ["AllWatersEasy", "AllWatersMedium"];
        assert_can_solve(`
	+waters=1
	....
	L.|.
	....
	L...
	`, s);
        assert_grid_eq(apply_strategies(`
	+waters=3
	....
	L.|.
	....
	L._.
	`, s).to_str(), `
	+waters=3.0
	....
	L.|.
	wwww
	L._.
	`);
    });

    test('test_aquariums', () => {
        const grid_one_aqua = "..\nL.";
        assert_cant_solve(grid_one_aqua);
        assert_can_solve("+aqua=1:1\n" + grid_one_aqua);
        assert_can_solve("+aqua=0:0\n" + grid_one_aqua);
        const grid_two_aqua = "...#\nL.L/";
        assert_cant_solve("+aqua=1:1\n" + grid_two_aqua);
        assert_can_solve("+aqua=1:1\n+aqua=0.5:1\n" + grid_two_aqua);
        assert_can_solve("+aqua=1:0\n+aqua=0.5:1\n" + grid_two_aqua);
        assert_can_solve("+aqua=0:0\n" + grid_two_aqua);
        const grid_three_aqua = `
	h....
	2....
	.L.L/
	`;
        assert_cant_solve(grid_three_aqua);
        assert_can_solve("+aqua=1:1\n" + grid_three_aqua);
        assert_can_solve("+aqua=1:0\n" + grid_three_aqua);
        assert_can_solve("+aqua=0:1\n.x\nL/");
        // Like level 5x2, uses a bunch of aquarium logics
        assert_can_solve(`
	+aqua=0.5:1
	+aqua=1.0:1
	+aqua=2.0:1
	+aqua=3.0:1
	+aqua=6.0:2
	..............
	|.|.L.|.|╲|...
	..............
	|.|.....|.|...
	..............
	L.L._._.L.L._.
	`);
        assert_cant_solve(`
	+aqua=0.0:1
	+waters=3.0
	#.##
	|/L.
	ww#.
	|.L/
	ww..
	L.L.
	`);
    });

    test('test_propagate_nowater', () => {
        assert_can_solve(`
	x##.
	|╲|/
	wwww
	L._.
	`);
        assert_cant_solve(`
	+aqua=0.0:1
	h....
	.xxxx
	.|...
	1..xx
	.L/L.
	`);
        assert_apply_strategies(`
	..##......##..
	|.L.|._...L.|.
	..##xx##..##..
	|.L.|.L.|.L.|.
	..##..##..##..
	|.L.|.L.|.L.|.
	......##......
	L._._.L.L._._.
	`, `
	xx##xxxxxx##xx
	|.L.|._...L.|.
	xx##xx##..##..
	|.L.|.L.|.L.|.
	..##..##..##..
	|.L.|.L.|.L.|.
	......##......
	L._._.L.L._._.
	`, ["FullPropagateNoWater"]);
    });

    test('test_cell_hints', () => {
        const g = str_grid(`
	+cellhint=2:2:3.5
	wwwwwwwwww
	|._._._...
	www....www
	|.L/L.L/|.
	ww......ww
	|.L.L.L.|.
	ww..ww..ww
	|.L.L.L.|.
	wwwwwwwwww
	L._._._._.
	`);
        expect(g.get_cell(2, 2).hints()!.adj_water_count).toBe(3.5);
        expect(g.get_cell(2, 2).hints()!.adj_water_count_type).toBe(E.HintType.Hidden);
        expect(g.are_hints_satisfied()).toBe(false);
        expect(g.count_water_adj(2, 2)).toBe(2.0);
        expect(g.together_waters_adj(2.0, 2, 2)).toBe(E.HintType.Separated);
        expect(g.count_water_adj(0, 1)).toBe(4.5);
        g.get_cell(1, 1).put_water(E.Corner.BottomRight);
        expect(g.are_hints_satisfied()).toBe(false);
        g.get_cell(1, 2).put_water(E.Corner.BottomRight);
        expect(g.count_water_adj(2, 2)).toBe(3.5);
        expect(g.are_hints_satisfied()).toBe(true);
        expect(g.together_waters_adj(2.0, 2, 2)).toBe(E.HintType.Separated);
        g.get_cell(1, 3).put_water(E.Corner.TopLeft);
        expect(g.together_waters_adj(2.0, 2, 2)).toBe(E.HintType.Separated);
        expect(g.are_hints_satisfied()).toBe(false);
        g.get_cell(2, 2).put_water(E.Corner.TopLeft);
        expect(g.together_waters_adj(2.0, 2, 2)).toBe(E.HintType.Together);
        expect(g.are_hints_satisfied()).toBe(false);
        g.undo();
        g.undo();
        g.get_cell(2, 1).put_water(E.Corner.TopLeft);
        expect(g.are_hints_satisfied()).toBe(false);
        g.get_cell(2, 1).remove_content(E.Corner.TopLeft);
        expect(g.are_hints_satisfied()).toBe(true);

        assert_can_solve(`
	+cellhint=1:1:2
	##..
	L.L.
	..##
	L.L.
	`);
        assert_can_solve(`
	+cellhint=1:1:3
	##..
	L.L.
	....
	L._.
	`);
        assert_cant_solve(`
	+cellhint=1:1:2
	##..
	L.L.
	....
	L.L.
	`);
        assert_can_solve(`
	+cellhint=1:1:2
	h....
	.##..
	.L.|.
	2....
	.L.L.
	`);
        assert_can_solve(`
	+cellhint=1:1:1
	h....
	2....
	.L.|.
	.##..
	.L.L.
	`);
        assert_can_solve(`
	+cellhint=1:1:2
	h....
	..#..
	}|╲|.
	.....
	.L.L.
	`);
        // Advanced
        assert_can_solve(`
	+cellhint=1:1:3
	h2.....
	.......
	.L.L._.
	.....##
	.L._.L.
	`);
        assert_can_solve(`
	+cellhint=1:1:1.5
	.#..
	|╲|.
	....
	L.L.
	`);
        assert_apply_strategies(`
	+cellhint=1:1:1.5
	....
	|.L.
	W#..
	L/L.
	`);
        assert_apply_strategies(`
	+cellhint=1:1:2.0
	#X..
	|/L.
	....
	L.L.
	`);
        // Using two cellhints
        assert_apply_strategies(`
	+cellhint=1:1:3.0
	+cellhint=1:2:1.0
	WW....
	L.L.L.
	WW....
	L.L.L.
	`);
        assert_apply_strategies(`
	+cellhint=1:1:2.5
	+cellhint=2:2:1.0
	....#W
	L.L.L/
	......
	L.L.L/
	......
	L.L.L/
	`);
        // Can't do anything if one is not contained in the other
        assert_apply_strategies(`
	+cellhint=1:1:3.0
	+cellhint=1:2:1.0
	........
	L.L.L.L.
	........
	L.L.L.L.
	`);
    });

    test('test_cell_hints_together', () => {
        const assert_cell_hints_together = (s: string, type: E.HintType = E.HintType.Together) => {
            const g = str_grid(s);
            expect(g.together_waters_adj(1.0, 1, 1)).toBe(type);
        };
        const assert_cell_hints_separated = (s: string) => {
            assert_cell_hints_together(s, E.HintType.Separated);
        };

        assert_cell_hints_separated(`
	ww..
	L.L.
	..ww
	L.L.
	`);
        assert_cell_hints_together(`
	wwww
	L.L.
	..ww
	L.L.
	`);
        assert_cell_hints_separated(`
	ww.w
	L.L/
	..ww
	L.L.
	`);
        assert_cell_hints_together(`
	wwww
	L.L/
	..ww
	L.L.
	`);
        assert_cell_hints_separated(`
	ww.w
	L.L╲
	wwww
	L.L.
	`);
        assert_cell_hints_together(`
	ww.w
	L.L/
	wwww
	L.L.
	`);
        assert_cell_hints_together(`
	ww....
	L.L.L.
	.www..
	L╲L.L.
	......
	L.L.L.
	`);
    });

    test('test_cell_hints_together_strat', () => {
        // Basic
        assert_apply_strategies(`
	+cellhint=1:1:{1.5}
	X#XX##
	L/L/L.
	..##..
	L.L.|.
	.#X#..
	L/L/L.
	`, "", ["BasicTogetherCellHints"]);
        assert_apply_strategies(`
	+cellhint=1:1:{?}
	XXX#XX
	L/L/L/
	##.w##
	L.L/L.
	X##XXX
	L/L/L/
	`, "", ["BasicTogetherCellHints"]);
        // Advanced together
        assert_apply_strategies(`
	+cellhint=1:1:{3.0}
	##WW..
	L.L.L.
	..WW##
	L.L.L.
	`, "", ["BasicTogetherCellHints", "TogetherSeparateCellHints"]);
        assert_apply_strategies(`
	+cellhint=1:1:{2.0}
	##....
	L.L.L.
	....##
	L.L.L.
	`, "", ["BasicTogetherCellHints", "TogetherSeparateCellHints"]);
        assert_apply_strategies(`
	+cellhint=1:1:{2.0}
	##WW..
	L.L.L.
	X#..##
	L/L.L.
	`, "", ["BasicTogetherCellHints", "TogetherSeparateCellHints"]);
        assert_apply_strategies(`
	+cellhint=1:1:{2.0}
	wW..XX
	L/L.L.
	..XXXX
	L/L.L.
	`, "", ["BasicTogetherCellHints", "TogetherSeparateCellHints"]);
        assert_apply_strategies(`
	+cellhint=1:1:{?}
	w.....
	L/L.L.
	......
	L/L.L.
	`, "", ["BasicTogetherCellHints", "TogetherSeparateCellHints"]);

        // Advanced separate
        assert_apply_strategies(`
	+cellhint=0:1:-1.0-
	..##W#
	L/L/L/
	`, "", ["TogetherSeparateCellHints"]);
        assert_apply_strategies(`
	+cellhint=1:1:-?-
	WWXXWW
	L.|.L.
	XXXXXX
	L._._.
	`);
        assert_apply_strategies(`
	+cellhint=1:1:-3.0-
	WW....
	L.L.L.
	####WW
	L.L.L.
	`);
        assert_apply_strategies(`
	+cellhint=0:1:-2.0-
	WWXXWW
	L.L.L.
	`);
        assert_apply_strategies(`
	+cellhint=1:1:-2.0-
	WW##..
	L.L.L.
	####..
	L.L.L.
	`);
        assert_apply_strategies(`
	+cellhint=1:1:-1.5-
	XXwXXW
	L.L/./
	####W#
	L.L.L/
	`);
        // Together with shortest path technique
        assert_apply_strategies(`
	+cellhint=0:1:{1.5}
	XXWWW#
	L.L.L/
	XXXXXX
	L.L.L.
	`);
        assert_apply_strategies(`
	+cellhint=1:1:{2.0}
	XX..XX
	L.L.L.
	..ww..
	L.L.L.
	`);
        assert_apply_strategies(`
	+cellhint=1:1:{3.0}
	ww..XX
	L.L.|.
	....XX
	L.L.L.
	`);
        assert_apply_strategies(`
	+cellhint=1:1:{1.5}
	...xXX
	L._/L.
	xxxxxx
	L.L.L.
	X...XX
	L/L.L.
	`);
        assert_apply_strategies(`
	+cellhint=1:2:-?-
	WWWWXX..
	L._.|.|.
	XXXXXXWW
	L._._.L.
	`);
        assert_apply_strategies(`
	+cellhint=1:1:{3.0}
	XXXX..
	L.L.|.
	XX....
	L.L.L.
	....ww
	L.L.L.
	`);
    });
});

