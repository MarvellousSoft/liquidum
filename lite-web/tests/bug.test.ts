import { E } from '../src/engine/E';
import { GridImpl, Content, PureCell } from '../src/engine/GridImpl';
import { describe, it, expect } from 'vitest';

describe('Bugs', () => {
    it('test_air_across_diagonal_bug', () => {
        const gridData = {
            cells: [
                [ { c_left: Content.NoWater, c_right: Content.NoWater, type: E.CellType.IncDiag } ],
            ],
            wall_right: [[false]],
            wall_bottom: [[false]]
        };

        const grid = new GridImpl(1, 1);
        grid.pure_cells = gridData.cells.map(row => row.map(c => {
            const p = new PureCell();
            p.c_left = c.c_left;
            p.c_right = c.c_right;
            p.type = c.type;
            return p;
        }));

        grid.get_cell(0, 0).remove_content(E.Corner.TopLeft, false, true);

        expect(grid.get_cell(0, 0).pure()._content_at(E.Corner.BottomRight)).toBe(Content.NoWater);
    });

    it('test_horizontal_airs_bug', () => {
        const gridData = {
            cells: [
                [ { c_left: Content.NoWater, c_right: Content.NoWater, type: E.CellType.Single }, { c_left: Content.NoWater, c_right: Content.NoWater, type: E.CellType.Single } ],
            ],
            wall_right: [[false, false]],
            wall_bottom: [[false, false]]
        };

        const grid = new GridImpl(1, 2);
        grid.pure_cells = gridData.cells.map(row => row.map(c => {
            const p = new PureCell();
            p.c_left = c.c_left;
            p.c_right = c.c_right;
            p.type = c.type;
            return p;
        }));

        grid.get_cell(0, 0).remove_content(E.Corner.TopLeft, false, true);

        expect(grid.get_cell(0, 1).pure()._content_at(E.Corner.TopLeft)).toBe(Content.Nothing);
    });

    it('test_horizontal_airs_with_diagonal_bug', () => {
        const gridData = {
            cells: [
                [ { c_left: Content.NoWater, c_right: Content.NoWater, type: E.CellType.Single }, { c_left: Content.NoWater, c_right: Content.NoWater, type: E.CellType.IncDiag } ],
            ],
            wall_right: [[false, false]],
            wall_bottom: [[false, false]]
        };

        const grid = new GridImpl(1, 2);
        grid.pure_cells = gridData.cells.map(row => row.map(c => {
            const p = new PureCell();
            p.c_left = c.c_left;
            p.c_right = c.c_right;
            p.type = c.type;
            return p;
        }));

        grid.get_cell(0, 0).remove_content(E.Corner.TopLeft, false, true);

        expect(grid.get_cell(0, 1).pure()._content_at(E.Corner.BottomRight)).toBe(Content.NoWater);
    });

    it('test_add_air_horizontal', () => {
        const gridData = {
            cells: [
                [ { c_left: Content.Nothing, c_right: Content.Nothing, type: E.CellType.Single }, { c_left: Content.Nothing, c_right: Content.Nothing, type: E.CellType.Single } ],
            ],
            wall_right: [[false, false]],
            wall_bottom: [[false, false]]
        };

        const grid = new GridImpl(1, 2);
        grid.pure_cells = gridData.cells.map(row => row.map(c => {
            const p = new PureCell();
            p.c_left = c.c_left;
            p.c_right = c.c_right;
            p.type = c.type;
            return p;
        }));

        grid.get_cell(0, 0).put_nowater(E.Corner.TopLeft, false, true);

        expect(grid.get_cell(0, 1).pure()._content_at(E.Corner.TopLeft)).toBe(Content.NoWater);
    });

    it('test_remove_water_disconnected', () => {
        const gridData = {
            cells: [
                [ { c_left: Content.Water, c_right: Content.Water, type: E.CellType.Single }, { c_left: Content.Nothing, c_right: Content.Nothing, type: E.CellType.Single }, { c_left: Content.Water, c_right: Content.Water, type: E.CellType.Single } ],
                [ { c_left: Content.Nothing, c_right: Content.Nothing, type: E.CellType.Single }, { c_left: Content.Nothing, c_right: Content.Nothing, type: E.CellType.Single }, { c_left: Content.Nothing, c_right: Content.Nothing, type: E.CellType.Single } ],
            ],
            wall_right: [[false, false, false], [false, false, false]],
            wall_bottom: [[false, false, false], [false, false, false]]
        };

        const grid = new GridImpl(2, 3);
        grid.pure_cells = gridData.cells.map(row => row.map(c => {
            const p = new PureCell();
            p.c_left = c.c_left;
            p.c_right = c.c_right;
            p.type = c.type;
            return p;
        }));

        grid.get_cell(0, 0).remove_content(E.Corner.TopLeft, false, false);

        expect(grid.get_cell(0, 2).pure()._content_at(E.Corner.TopLeft)).toBe(Content.Water);
    });

    it('test_remove_air_enclosed', () => {
        const gridData = {
            cells: [
                [ 
                    { c_left: Content.Nothing, c_right: Content.Nothing, type: E.CellType.DecDiag }, 
                    { c_left: Content.Nothing, c_right: Content.Nothing, type: E.CellType.IncDiag }, 
                    { c_left: Content.Nothing, c_right: Content.Nothing, type: E.CellType.DecDiag }, 
                    { c_left: Content.Nothing, c_right: Content.Nothing, type: E.CellType.IncDiag } 
                ],
            ],
            wall_right: [[false, false, false, false]],
            wall_bottom: [[false, false, false, false]]
        };

        const grid = new GridImpl(1, 4);
        grid.pure_cells = gridData.cells.map(row => row.map(c => {
            const p = new PureCell();
            p.c_left = c.c_left;
            p.c_right = c.c_right;
            p.type = c.type;
            return p;
        }));

        grid.get_cell(0, 0).put_nowater(E.Corner.TopRight, false, true);
        grid.get_cell(0, 2).put_nowater(E.Corner.TopRight, false, true);

        expect(grid.get_cell(0, 0).pure()._content_at(E.Corner.TopRight)).toBe(Content.NoWater);
        expect(grid.get_cell(0, 2).pure()._content_at(E.Corner.TopRight)).toBe(Content.NoWater);

        grid.get_cell(0, 0).remove_content(E.Corner.TopRight, false, true);

        expect(grid.get_cell(0, 2).pure()._content_at(E.Corner.TopRight)).toBe(Content.NoWater);
    });
});
