import { describe, test, expect } from 'vitest';
import { E } from '../src/engine/E';
import { GridImpl, Content } from '../src/engine/GridImpl';
import { LoadMode, WaterPosition } from '../src/engine/Grid';
import { Vector3i } from '../src/engine/Math';

const TopLeft = E.Corner.TopLeft;
const TopRight = E.Corner.TopRight;
const BottomLeft = E.Corner.BottomLeft;
const BottomRight = E.Corner.BottomRight;
const Satisfied = E.HintStatus.Satisfied;
const Wrong = E.HintStatus.Wrong;
const Normal = E.HintStatus.Normal;

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

function _cmp_waters(a: WaterPosition[], b: Vector3i[]): void {
    expect(a.length).toBe(b.length);
    for (let i = 0; i < a.length; i++) {
        expect(a[i].i).toBe(b[i].x);
        expect(a[i].j).toBe(b[i].y);
        expect(a[i].loc).toBe(b[i].z);
    }
}

describe('Grid Tests ported from Godot GridTests.gd', () => {
    test('test_simple', () => {
        const simple = `
wwwx
L../
#..w
L╲_╲
`;
        const g = new GridImpl(2, 2);
        expect(g.get_cell(0, 0).water_full()).toBe(false);
        g.load_from_str(simple, LoadMode.Testing);
        // Check waters make sense
        expect(g.get_cell(0, 0).water_full()).toBe(true);
        for (const corner of [BottomLeft, BottomRight, TopLeft, TopRight]) {
            expect(g.get_cell(0, 0).water_at(corner)).toBe(true);
        }
        expect(g.get_cell(0, 1).water_at(TopLeft)).toBe(true);
        expect(g.get_cell(0, 1).water_at(BottomRight)).toBe(false);
        expect(g.get_cell(1, 1).water_at(TopRight)).toBe(true);
        expect(g.get_cell(1, 1).water_at(BottomLeft)).toBe(false);
        // Check nowater
        expect(g.get_cell(0, 0).nowater_at(TopLeft)).toBe(false);
        expect(g.get_cell(0, 1).nowater_at(TopLeft)).toBe(false);
        expect(g.get_cell(0, 1).nowater_at(BottomRight)).toBe(true);
        expect(!g.get_cell(1, 0).nowater_at(BottomLeft) && !g.get_cell(1, 0).water_at(BottomRight)).toBe(true);
        // Check block
        expect(g.get_cell(1, 0).block_full()).toBe(false);
        expect(g.get_cell(1, 0).block_at(BottomLeft)).toBe(true);
        // Check diag walls
        expect(g.get_cell(0, 0).wall_at(E.Walls.DecDiag)).toBe(false);
        expect(g.get_cell(0, 1).wall_at(E.Walls.IncDiag)).toBe(true);
        expect(g.get_cell(0, 1).wall_at(E.Walls.DecDiag)).toBe(false);
        expect(g.get_cell(1, 1).wall_at(E.Walls.DecDiag)).toBe(true);
        // Check walls
        expect(g.get_cell(0, 0).wall_at(E.Walls.Left)).toBe(true);
        expect(g.get_cell(0, 0).wall_at(E.Walls.Right)).toBe(false);
        expect(g.get_cell(0, 0).wall_at(E.Walls.Bottom)).toBe(true);
        expect(g.get_cell(0, 0).wall_at(E.Walls.Top)).toBe(true);
        expect(g.get_cell(1, 1).wall_at(E.Walls.Left)).toBe(false);
        expect(g.get_cell(1, 1).wall_at(E.Walls.Right)).toBe(true);

        assert_grid_eq(simple, g.to_str());
    });

    test('test_put_water_one_cell', () => {
        let g = str_grid("..\n..");
        expect(g.get_cell(0, 0).nothing_full()).toBe(true);
        expect(g.get_cell(0, 0).nothing_at(TopLeft)).toBe(true);
        g.get_cell(0, 0).put_water(BottomRight);
        assert_grid_eq(g.to_str(), "ww\nL.");
        g = str_grid("..\nL╲");
        g.get_cell(0, 0).put_water(TopRight);
        assert_grid_eq(g.to_str(), ".w\nL╲");
        g.get_cell(0, 0).put_water(TopRight);
        assert_grid_eq(g.to_str(), ".w\nL╲");
        g.get_cell(0, 0).put_water(BottomLeft);
        assert_grid_eq(g.to_str(), "ww\nL╲");
        g.undo();
        assert_grid_eq(g.to_str(), ".w\nL╲");
        g.redo();
        assert_grid_eq(g.to_str(), "ww\nL╲");
    });

    const big_level = `
......
|....╲
......
|╲./|.
......
L../.╲
#.....
L╲_╲_.
`;

    test('test_water_big_level', () => {
        const g = str_grid(big_level);
        // Test a "bucket" of water
        g.get_cell(1, 1).put_water(TopLeft);
        g.get_cell(2, 2).put_water(BottomLeft);
        assert_grid_eq(g.to_str(), `
......
|....╲
.ww...
|╲./|.
...ww.
L../.╲
#..www
L╲_╲_.
`);
        // Test flooding up through "caves"
        g.undo();
        g.get_cell(1, 1).put_water(BottomRight);
        expect(g.get_cell(1, 0).water_at(BottomLeft)).toBe(true);
        // Other direction
        g.undo();
        expect(g.get_cell(1, 1).water_at(BottomRight)).toBe(false);
        g.get_cell(1, 0).put_water(BottomLeft);
        expect(g.get_cell(1, 1).water_at(BottomRight)).toBe(true);
        g.undo();
        g.get_cell(0, 0).put_water(TopLeft);
        g.undo();
        g.redo();
        g.get_cell(3, 1).put_water(BottomLeft);
        g.redo();
        g.redo();
        assert_grid_eq(g.to_str(), `
wwwww.
|....╲
.ww.ww
|╲./|.
.....w
L../.╲
#ww...
L╲_╲_.
`);
        g.get_cell(3, 0).remove_content(TopRight);
        g.get_cell(1, 0).put_water(BottomLeft);
        g.get_cell(1, 2).put_nowater(BottomRight);
        g.get_cell(1, 1).put_nowater(BottomRight);
        assert_grid_eq(g.to_str(), `
......
|....╲
.wwxxx
|╲./|.
www..w
L../.╲
#.....
L╲_╲_.
`);
        expect(g.col_hints()[0].water_count).toBe(-1.0);
        g.col_hints()[0].water_count = 1.5;
        expect(g.col_hints()[0].water_count).toBe(1.5);
        g.row_hints()[1].water_count = 1.0;
        expect(g.are_hints_satisfied()).toBe(true);
        g.col_hints()[2].water_count = 0.5;
        expect(g.are_hints_satisfied()).toBe(true);
        g.row_hints()[0].water_count = 0.5;
        expect(g.are_hints_satisfied()).toBe(false);
    });

    test('test_remove_water_bug', () => {
        const g = str_grid(`
xx
|.
ww
L.
`);
        g.get_cell(1, 0).remove_content(BottomLeft);
        assert_grid_eq(g.to_str(), `
xx
|.
..
L.
`);
    });

    function _flood_all(bef: string, aft: string): void {
        const g = str_grid(bef);
        g.flood_all();
        assert_grid_eq(g.to_str(), aft);
        expect(g.flood_all()).toBe(false);
    }

    test('test_flood_all', () => {
        _flood_all(".w\n|.\n..\nL.", "ww\n|.\nww\nL.");
        _flood_all("ww\n|.\nxx\nL.", "ww\n|.\nww\nL.");
        _flood_all(".w\n|╲\n..\nL.", ".w\n|╲\n..\nL.");
        _flood_all(".w\n|/\n..\nL.", ".w\n|/\nww\nL.");
    });

    test('test_boat_hint', () => {
        const s = `
B...
.h2.
10..
..|.
.2..
..L.
`;
        assert_grid_eq(str_grid(s).to_str(), s);
    });

    test('test_boat_place_remove', () => {
        const g = str_grid(`
+boats=1
B.......
.h......
1.......
........
.6......
......_.
........
........
`);
        // Can't place on top of wall
        expect(g.get_cell(1, 2).put_boat()).toBe(false);
        // Place water automatically below
        expect(g.get_cell(0, 1).put_boat()).toBe(true);
        expect(g.get_cell(1, 0).water_full()).toBe(true);
        g.undo();
        g.get_cell(1, 0).put_water(BottomLeft);
        expect(g.are_hints_satisfied()).toBe(false);
        expect(g.get_cell(0, 1).has_boat()).toBe(false);
        expect(g.get_cell(0, 1).put_boat()).toBe(true);
        expect(g.get_cell(0, 1).has_boat()).toBe(true);
        expect(g.are_hints_satisfied()).toBe(true);
        // Water should destroy boat
        g.get_cell(0, 0).put_water(BottomRight);
        expect(g.get_cell(0, 1).has_boat()).toBe(false);
        expect(g.get_cell(0, 1).water_full()).toBe(true);
        g.undo();
        expect(g.are_hints_satisfied()).toBe(true);
        // Removing water should destroy boat
        g.get_cell(1, 2).remove_content(TopRight);
        expect(g.get_cell(0, 1).has_boat()).toBe(false);
        g.undo();
        expect(g.are_hints_satisfied()).toBe(true);
        // NoWater should flood through boats without deleting them
        g.get_cell(0, 0).put_nowater(TopLeft, true, true);
        expect(g.get_cell(0, 0).nowater_full()).toBe(true);
        expect(g.get_cell(0, 1).has_boat()).toBe(true);
        expect(g.get_cell(0, 2).nowater_full()).toBe(true);
    });

    test('test_load_content_only', () => {
        const g = str_grid("..\n|.\n..\nL.\n");
        assert_grid_eq(g.to_str(), "..\n|.\n..\nL.\n");
        // Assume we saved the puzzle to file, and the user edited it to add a wall
        // and make the level easier, let's not accept that
        g.load_from_str("ww\nL.\n..\nL.\n", LoadMode.ContentOnly);
        assert_grid_eq(g.to_str(), "ww\n|.\nww\nL.");
    });

    test('test_aquarium_hints', () => {
        const g = str_grid("+aqua=1:1\n..\n..\n..\n..");
        expect(g.are_hints_satisfied()).toBe(false);
        expect(g.grid_hints().expected_aquariums).toEqual({ 1.0: 1 });
        expect(g.aquarium_hints_status()).toBe(Normal);
        g.get_cell(0, 0).put_water(TopLeft);
        expect(g.aquarium_hints_status()).toBe(Normal);
        g.undo();
        g.get_cell(1, 0).put_water(TopLeft);
        expect(g.aquarium_hints_status()).toBe(Satisfied);
        expect(g.are_hints_satisfied()).toBe(true);
    });

    test('test_together_rules', () => {
        let g = str_grid(`
h......
4......
}L.L.L.
`);
        g.get_cell(0, 0).put_water(TopRight);
        g.get_cell(0, 2).put_water(TopRight);
        expect(g.are_hints_satisfied()).toBe(false);
        g.get_cell(0, 2).remove_content(TopRight);
        g.get_cell(0, 1).put_water(TopRight);
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
        g.get_cell(0, 0).put_water(TopRight);
        g.get_cell(2, 0).put_water(TopRight);
        expect(g.are_hints_satisfied()).toBe(false);
        g.get_cell(2, 0).remove_content(TopRight);
        g.get_cell(1, 0).put_water(TopRight);
        expect(g.are_hints_satisfied()).toBe(true);
    });

    test('test_put_wall', () => {
        let g = new GridImpl(1, 2);
        g.get_cell(0, 0).put_water(TopLeft);
        g.get_cell(0, 0).put_wall(E.Walls.DecDiag);
        expect(g.get_cell(0, 0).water_full()).toBe(false);
        expect(g.get_cell(0, 0).water_at(BottomLeft)).toBe(true);
        g.get_cell(0, 0).remove_content(BottomLeft, false);
        expect(g.get_cell(0, 0).water_at(TopRight)).toBe(true);
        g.remove_wall_from_idx(0, 0, 1, 1, false);
        expect(g.get_cell(0, 0).water_at(BottomLeft)).toBe(true);
        g = new GridImpl(3, 3);
        g.put_wall_from_idx(3, 3, 0, 0);
        const dec_dig = `
......
|╲....
......
|..╲..
......
L._._╲
`;
        assert_grid_eq(g.to_str(), dec_dig);
        g.undo();
        assert_grid_eq(g.to_str(), new GridImpl(3, 3).to_str());
        g.put_wall_from_idx(0, 0, 3, 3);
        assert_grid_eq(g.to_str(), dec_dig);
    });

    test('test_put_nowater_with_boat', () => {
        const g = str_grid(`
bb..
|...
w.ww
L/L.
`);
        g.get_cell(1, 1).put_nowater(BottomRight);
        assert_grid_eq(g.to_str(), `
bb..
|...
w.xx
L/L.
`);
    });

    test('test_resize', () => {
        const initial = "ww\nL.";
        const g = str_grid(initial);
        g.add_row();
        const with_row = "ww\n|.\nww\nL.";
        assert_grid_eq(g.to_str(), with_row);
        g.undo();
        assert_grid_eq(g.to_str(), initial);
        g.redo();
        g.add_row();
        g.rem_row();
        assert_grid_eq(g.to_str(), with_row);
        g.add_col();
        assert_grid_eq(g.to_str(), "wwww\n|...\nwwww\nL._.");
        g.undo();
        assert_grid_eq(g.to_str(), with_row);
        g.redo();
        g.rem_col();
        assert_grid_eq(g.to_str(), with_row);
    });

    test('test_flood_which', () => {
        const grid_str = `
....
|.L.
%s
L._/
`;
        let g = str_grid(grid_str.replace('%s', "...."));
        _cmp_waters(g.get_cell(0, 0).water_would_flood_which(E.Corner.TopLeft), [new Vector3i(0, 0, E.Waters.Single), new Vector3i(1, 0, E.Waters.Single), new Vector3i(1, 1, E.Waters.TopLeft)]);
        _cmp_waters(g.get_cell(0, 0).boat_would_flood_which(), [new Vector3i(1, 0, E.Waters.Single), new Vector3i(1, 1, E.Waters.TopLeft)]);
        g = str_grid(grid_str.replace('%s', "www."));
        _cmp_waters(g.get_cell(0, 0).water_would_flood_which(E.Corner.TopLeft), [new Vector3i(0, 0, E.Waters.Single)]);
        _cmp_waters(g.get_cell(0, 0).boat_would_flood_which(), []);
    });

    test('test_noboat', () => {
        const grid_str = `
%s
L/
`;
        let g = str_grid(grid_str.replace('%s', ".."));
        g.get_cell(0, 0).put_nowater(TopLeft);
        g.get_cell(0, 0).put_noboat(BottomRight);
        assert_grid_eq(g.to_str(), grid_str.replace('%s', "xy"));
        g.get_cell(0, 0).put_noboat(TopLeft);
        assert_grid_eq(g.to_str(), grid_str.replace('%s', "zy"));
        g.get_cell(0, 0).put_nowater(TopLeft);
        assert_grid_eq(g.to_str(), grid_str.replace('%s', "zy"));
        g.get_cell(0, 0).put_nowater(BottomRight);
        assert_grid_eq(g.to_str(), grid_str.replace('%s', "zz"));
        g.get_cell(0, 0).remove_content(TopLeft);
        assert_grid_eq(g.to_str(), grid_str.replace('%s', ".z"));
        g.undo();
        g.get_cell(0, 0).remove_noboat(TopLeft);
        g.get_cell(0, 0).remove_nowater(BottomRight);
        assert_grid_eq(g.to_str(), grid_str.replace('%s', "xy"));
        g = str_grid(`
..
|.
yy
L.
`);
        expect(g.get_cell(0, 0).boat_possible()).toBe(true);
        _cmp_waters(g.get_cell(0, 0).water_would_flood_which(TopLeft), [new Vector3i(0, 0, E.Waters.Single), new Vector3i(1, 0, E.Waters.Single)]);
        _cmp_waters(g.get_cell(0, 0).boat_would_flood_which(), [new Vector3i(1, 0, E.Waters.Single)]);
        g.get_cell(0, 0).put_noboat(TopLeft);
        // Ignore NoBoat, just like we ignore NoWater when placing water
        expect(g.get_cell(0, 0).boat_possible()).toBe(true);
    });

    test('test_rotate_mirror', () => {
        const grid = str_grid(`
#.
L/
..
|.
#.
L╲
`);
        grid.mirror_horizontal();
        assert_grid_eq(grid.to_str(), `
.#
L╲
..
|.
.#
L/
`);
        grid.mirror_vertical();
        assert_grid_eq(grid.to_str(), `
.#
|╲
..
L.
.#
L/
`);
        grid.rotate_clockwise();
        assert_grid_eq(grid.to_str(), `
#....#
L╲L._/
`);
        grid.mirror_horizontal();
        assert_grid_eq(grid.to_str(), `
#....#
L╲_.L/
`);
        grid.mirror_vertical();
        assert_grid_eq(grid.to_str(), `
#....#
L/_.L╲
`);
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
        expect(g.get_cell(2, 2).hints().adj_water_count).toBe(3.5);
        expect(g.get_cell(2, 2).hints().adj_water_count_type).toBe(E.HintType.Hidden);
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
    });

    function assert_cell_hints_together(s: string, type: E.HintType = E.HintType.Together): void {
        const g = str_grid(s);
        expect(g.together_waters_adj(1.0, 1, 1)).toBe(type);
    }

    function assert_cell_hints_separated(s: string): void {
        assert_cell_hints_together(s, E.HintType.Separated);
    }

    test('test_cell_hints_together', () => {
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
});
