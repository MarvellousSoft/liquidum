import { describe, it, expect } from 'vitest';
import { GridImpl } from '../src/engine/GridImpl';
import { Content, CellType, Corner, parseGridData } from '../src/model/GridData';
import { E } from '../src/engine/E';
import { LoadMode } from '../src/engine/Grid';

describe('Mistake & Partial Solution Logic', () => {
  it('allows all placements in editor mode (empty grid without solution)', () => {
    const emptyGridStr = `
....
....
....
....
`;
    const grid = GridImpl.from_str(emptyGridStr, LoadMode.Testing);
    expect(grid.editor_mode()).toBe(true);
    expect(grid.is_corner_partially_valid(Content.Water, 0, 0, E.Corner.TopLeft)).toBe(true);
    expect(grid.is_corner_partially_valid(Content.Boat, 0, 0, E.Corner.TopRight)).toBe(true);
    expect(grid.is_corner_partially_valid(Content.NoWater, 0, 0, E.Corner.TopLeft)).toBe(true);
  });

  it('validates water placement against solution', () => {
    // 2x2 grid with vertical wall between col 0 and col 1
    // Col 1 has water, Col 0 does not
    const levelStr = `
..ww
..|.
..ww
..|.
`;
    const grid = GridImpl.from_str(levelStr, LoadMode.Solution);
    expect(grid.editor_mode()).toBe(false);

    // (0, 1) has water in solution -> valid
    expect(grid.is_corner_partially_valid(Content.Water, 0, 1, E.Corner.TopLeft)).toBe(true);
    
    // (0, 0) does not have water in solution -> invalid (mistake!)
    expect(grid.is_corner_partially_valid(Content.Water, 0, 0, E.Corner.TopLeft)).toBe(false);

    // Air / NoWater is always valid (pencil marking)
    expect(grid.is_corner_partially_valid(Content.NoWater, 0, 0, E.Corner.TopLeft)).toBe(true);
    expect(grid.is_corner_partially_valid(Content.NoBoat, 0, 0, E.Corner.TopLeft)).toBe(true);

    // put_water on invalid cell returns 0.0 (fails)
    const cell00 = grid.get_cell(0, 0) as any;
    expect(cell00.put_water(E.Corner.TopLeft)).toBe(0.0);
    expect(cell00.water_at(E.Corner.TopLeft)).toBe(false);

    // put_water on valid cell succeeds
    const cell01 = grid.get_cell(0, 1) as any;
    expect(cell01.put_water(E.Corner.TopLeft)).toBeGreaterThan(0.0);
    expect(cell01.water_at(E.Corner.TopLeft)).toBe(true);
  });

  it('validates boat placement against solution and physical constraints', () => {
    // 3x2 grid with boat at (0, 0) floating on water at (1, 0)
    const levelStr = `
bb..
....
ww..
....
....
....
`;
    const grid = GridImpl.from_str(levelStr, LoadMode.Solution);
    expect(grid.editor_mode()).toBe(false);

    // (0, 0) has boat in solution
    expect(grid.is_corner_partially_valid(Content.Boat, 0, 0, E.Corner.TopRight)).toBe(true);
    // (0, 1) does NOT have boat in solution
    expect(grid.is_corner_partially_valid(Content.Boat, 0, 1, E.Corner.TopRight)).toBe(false);

    // Attempting to put boat at (0, 1) fails
    const cell01 = grid.get_cell(0, 1) as any;
    expect(cell01.put_boat()).toBe(false);

    // Boat on bottom row (row 2) fails due to bottom wall
    const cell20 = grid.get_cell(2, 0) as any;
    expect(cell20.put_boat()).toBe(false);

    // Valid boat placement puts boat and water below
    const cell00 = grid.get_cell(0, 0) as any;
    expect(cell00.put_boat()).toBe(true);
    expect(cell00.has_boat()).toBe(true);
  });

  it('preserves solution when converting to and from GridModelData', () => {
    const levelStr = `
..ww
..|.
..ww
..|.
`;
    const grid = GridImpl.from_str(levelStr, LoadMode.Solution);
    const data = grid.to_grid_data();
    expect(data.solution_c_left).toBeDefined();
    expect(data.solution_c_left![0][1]).toBe(Content.Water);
    expect(data.solution_c_left![0][0]).toBe(Content.Nothing);

    const reloaded = GridImpl.load_from_grid_data(data);
    expect(reloaded.editor_mode()).toBe(false);
    expect(reloaded.is_corner_partially_valid(Content.Water, 0, 1, E.Corner.TopLeft)).toBe(true);
    expect(reloaded.is_corner_partially_valid(Content.Water, 0, 0, E.Corner.TopLeft)).toBe(false);
  });
});
