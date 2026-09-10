import { E } from '../src/engine/E';
import { GridImpl, Content, PureCell } from '../src/engine/GridImpl';
import { describe, it, expect } from 'vitest';

describe('Physics Tests', () => {
    it('test_gravity_defying_bug', () => {
        const gridData = {
            cells: [
                [ { c_left: Content.Nothing, c_right: Content.Nothing, type: E.CellType.IncDiag } ],
                [ { c_left: Content.Nothing, c_right: Content.Nothing, type: E.CellType.DecDiag } ]
            ],
            wall_right: [[false], [false]],
            wall_bottom: [[false], [false]]
        };

        const grid = new GridImpl(2, 1);
        grid.pure_cells = gridData.cells.map(row => row.map(c => {
            const p = new PureCell();
            p.c_left = c.c_left;
            p.c_right = c.c_right;
            p.type = c.type;
            return p;
        }));

        grid.get_cell(1, 0).put_water(E.Corner.TopRight);
        grid.get_cell(0, 0).put_water(E.Corner.TopLeft);

        expect(grid.get_cell(0, 0).pure()._content_at(E.Corner.BottomRight)).toBe(Content.Nothing);
    });

    it('test_air_in_middle_of_pool_bug', () => {
        const gridData = {
            cells: [
                [ { c_left: Content.Nothing, c_right: Content.Nothing, type: E.CellType.Single } ],
                [ { c_left: Content.Nothing, c_right: Content.Nothing, type: E.CellType.Single } ],
                [ { c_left: Content.Nothing, c_right: Content.Nothing, type: E.CellType.Single } ],
                [ { c_left: Content.Nothing, c_right: Content.Nothing, type: E.CellType.Single } ]
            ],
            wall_right: [[false], [false], [false], [false]],
            wall_bottom: [[false], [false], [false], [false]]
        };

        const grid = new GridImpl(4, 1);
        grid.pure_cells = gridData.cells.map(row => row.map(c => {
            const p = new PureCell();
            p.c_left = c.c_left;
            p.c_right = c.c_right;
            p.type = c.type;
            return p;
        }));

        grid.get_cell(1, 0).put_water(E.Corner.TopLeft); 
        grid.get_cell(2, 0).put_water(E.Corner.TopLeft);
        grid.get_cell(3, 0).put_water(E.Corner.TopLeft);

        grid.get_cell(2, 0).put_nowater(E.Corner.TopLeft, false, false);

        expect(grid.get_cell(1, 0).pure()._content_at(E.Corner.TopLeft)).toBe(Content.Nothing);
        expect(grid.get_cell(2, 0).pure()._content_at(E.Corner.TopLeft)).toBe(Content.NoWater);
        expect(grid.get_cell(3, 0).pure()._content_at(E.Corner.TopLeft)).toBe(Content.Water);
    });

    it('test_place_water_falls_down', () => {
        const gridData = {
            cells: [
                [ { c_left: Content.Nothing, c_right: Content.Nothing, type: E.CellType.Single } ],
                [ { c_left: Content.Nothing, c_right: Content.Nothing, type: E.CellType.Single } ],
                [ { c_left: Content.Nothing, c_right: Content.Nothing, type: E.CellType.Single } ],
            ],
            wall_right: [[false], [false], [false]],
            wall_bottom: [[false], [false], [true]] // Bottom wall at the very bottom
        };

        const grid = new GridImpl(3, 1);
        grid.pure_cells = gridData.cells.map(row => row.map(c => {
            const p = new PureCell();
            p.c_left = c.c_left;
            p.c_right = c.c_right;
            p.type = c.type;
            return p;
        }));

        grid.get_cell(0, 0).put_water(E.Corner.TopLeft);
        grid.flood_all();

        expect(grid.get_cell(0, 0).pure()._content_at(E.Corner.TopLeft)).toBe(Content.Water);
        expect(grid.get_cell(2, 0).pure()._content_at(E.Corner.TopLeft)).toBe(Content.Water);
    });

    it('test_place_air_floats_up', () => {
        const gridData = {
            cells: [
                [ { c_left: Content.Block, c_right: Content.Block, type: E.CellType.Single } ],
                [ { c_left: Content.Nothing, c_right: Content.Nothing, type: E.CellType.Single } ],
                [ { c_left: Content.Nothing, c_right: Content.Nothing, type: E.CellType.Single } ],
            ],
            wall_right: [[false], [false], [false]],
            wall_bottom: [[false], [false], [false]]
        };

        const grid = new GridImpl(3, 1);
        grid.pure_cells = gridData.cells.map(row => row.map(c => {
            const p = new PureCell();
            p.c_left = c.c_left;
            p.c_right = c.c_right;
            p.type = c.type;
            return p;
        }));

        grid.get_cell(2, 0).put_nowater(E.Corner.TopLeft, false, true);

        expect(grid.get_cell(2, 0).pure()._content_at(E.Corner.TopLeft)).toBe(Content.NoWater);
        expect(grid.get_cell(1, 0).pure()._content_at(E.Corner.TopLeft)).toBe(Content.NoWater);
    });
});
