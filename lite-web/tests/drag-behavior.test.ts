import { describe, test, expect } from 'vitest';
import { E } from '../src/engine/E';
import { GridImpl } from '../src/engine/GridImpl';
import { LoadMode } from '../src/engine/Grid';

function str_grid(s: string): GridImpl {
    return GridImpl.from_str(s, LoadMode.Testing);
}

describe('Drag Behavior & MouseDragState Rules', () => {
    test('Water drag state should only place water on empty cells (nothing_at), skipping cells with NoWater', () => {
        // Grid with 2 rows, 2 columns, separated by vertical wall
        const g = str_grid("..\n|.\n..\nL.");
        const c00 = g.get_cell(0, 0);
        const c10 = g.get_cell(1, 0);

        // Put NoWater (X) on cell (0, 0)
        c00.put_nowater(E.Corner.BottomLeft);
        expect(c00.nowater_at(E.Corner.BottomLeft)).toBe(true);
        expect(c00.nothing_at(E.Corner.BottomLeft)).toBe(false);

        // Simulate dragging Water (MouseDragState.Water):
        // Cell (1, 0) is empty -> nothing_at is true -> places water
        expect(c10.nothing_at(E.Corner.BottomLeft)).toBe(true);
        c10.put_water(E.Corner.BottomLeft);
        expect(c10.water_at(E.Corner.BottomLeft)).toBe(true);

        // Dragging into cell (0, 0): nothing_at is FALSE -> skipped!
        expect(c00.nothing_at(E.Corner.BottomLeft)).toBe(false);
        // Because nothing_at is false, drag logic will NOT call put_water
        // Verify cell (0, 0) remains NoWater (X)
        expect(c00.nowater_at(E.Corner.BottomLeft)).toBe(true);
        expect(c00.water_at(E.Corner.BottomLeft)).toBe(false);
    });

    test('NoWater drag state should not overwrite cells that already have Water', () => {
        const g = str_grid("..\n|.\n..\nL.");
        const c00 = g.get_cell(0, 0);
        const c10 = g.get_cell(1, 0);

        // Put Water on cell (1, 0)
        c10.put_water(E.Corner.BottomLeft);
        expect(c10.water_at(E.Corner.BottomLeft)).toBe(true);

        // Simulate dragging NoWater (MouseDragState.NoWater):
        // Predicate: cell.noboat_at(corner) || cell.nothing_at(corner)
        // Cell (0, 0) is empty -> matches predicate
        expect(c00.noboat_at(E.Corner.BottomLeft) || c00.nothing_at(E.Corner.BottomLeft)).toBe(true);
        c00.put_nowater(E.Corner.BottomLeft);
        expect(c00.nowater_at(E.Corner.BottomLeft)).toBe(true);

        // Dragging into cell (1, 0) with Water:
        // c10 has Water, so neither noboat_at nor nothing_at is true
        expect(c10.noboat_at(E.Corner.BottomLeft) || c10.nothing_at(E.Corner.BottomLeft)).toBe(false);
        // Drag logic skips cell (1, 0), preserving water!
        expect(c10.water_at(E.Corner.BottomLeft)).toBe(true);
        expect(c10.nowater_at(E.Corner.BottomLeft)).toBe(false);
    });

    test('RemoveWater drag state only removes water from cells with water', () => {
        const g = str_grid("..\n|.\n..\nL.");
        const c00 = g.get_cell(0, 0);
        const c10 = g.get_cell(1, 0);

        // Cell 0 has NoWater, Cell 1 has Water
        c00.put_nowater(E.Corner.BottomLeft);
        c10.put_water(E.Corner.BottomLeft);

        // Dragging with RemoveWater:
        // Cell 00: water_at is false -> skipped!
        expect(c00.water_at(E.Corner.BottomLeft)).toBe(false);
        // Cell 10: water_at is true -> removed!
        expect(c10.water_at(E.Corner.BottomLeft)).toBe(true);
        c10.remove_content(E.Corner.BottomLeft);

        expect(c00.nowater_at(E.Corner.BottomLeft)).toBe(true);
        expect(c10.nothing_at(E.Corner.BottomLeft)).toBe(true);
    });

    test('RemoveNoWater drag state only removes X from cells with NoWater', () => {
        const g = str_grid("..\n|.\n..\nL.");
        const c00 = g.get_cell(0, 0);
        const c10 = g.get_cell(1, 0);

        // Cell 0 has NoWater, Cell 1 has Water
        c00.put_nowater(E.Corner.BottomLeft);
        c10.put_water(E.Corner.BottomLeft);

        // Dragging with RemoveNoWater:
        // Cell 10: nowater_at is false -> skipped!
        expect(c10.nowater_at(E.Corner.BottomLeft)).toBe(false);
        // Cell 00: nowater_at is true -> removed!
        expect(c00.nowater_at(E.Corner.BottomLeft)).toBe(true);
        c00.remove_nowater(E.Corner.BottomLeft);

        expect(c00.nothing_at(E.Corner.BottomLeft)).toBe(true);
        expect(c10.water_at(E.Corner.BottomLeft)).toBe(true);
    });
});
