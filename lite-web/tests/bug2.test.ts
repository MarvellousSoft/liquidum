import { E } from '../src/engine/E';
import { GridImpl, Content, PureCell } from '../src/engine/GridImpl';
import { describe, it, expect } from 'vitest';

describe('Bug 2', () => {
    it('test_bug2', () => {
        // level 03/01 data
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
        const cells = gridData.cells.map(row => row.map(c => {
            const p = new PureCell();
            p.c_left = c.c_left;
            p.c_right = c.c_right;
            p.type = c.type;
            return p;
        }));
        grid.pure_cells = cells;

        grid.get_cell(1, 0).put_water(E.Corner.TopLeft); 
        grid.get_cell(2, 0).put_water(E.Corner.TopLeft);
        grid.get_cell(3, 0).put_water(E.Corner.TopLeft);

        expect(grid.get_cell(1, 0).pure().c_left).toBe(Content.Water);
        expect(grid.get_cell(2, 0).pure().c_left).toBe(Content.Water);
        expect(grid.get_cell(3, 0).pure().c_left).toBe(Content.Water);

        grid.get_cell(2, 0).put_nowater(E.Corner.TopLeft, false, false);

        expect(grid.get_cell(1, 0).pure().c_left).toBe(Content.Nothing);
        expect(grid.get_cell(2, 0).pure().c_left).toBe(Content.NoWater);
        expect(grid.get_cell(3, 0).pure().c_left).toBe(Content.Water);
    });
});
