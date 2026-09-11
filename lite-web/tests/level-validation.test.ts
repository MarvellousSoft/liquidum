import { describe, it, expect } from 'vitest';
import { parseGridData, Content, CellType, isLevelComplete, HintType } from '../src/model/GridData';

describe('Level Validation', () => {
  it('should validate a simple completed grid without boats', () => {
    // 2x2 grid, all water
    const gridData = {
      cells: [
        [
          { c_left: Content.Water, c_right: Content.Water, type: CellType.Single },
          { c_left: Content.Water, c_right: Content.Water, type: CellType.Single }
        ],
        [
          { c_left: Content.Water, c_right: Content.Water, type: CellType.Single },
          { c_left: Content.Water, c_right: Content.Water, type: CellType.Single }
        ]
      ],
      row_hints: [
        { water_count: 2, water_count_type: HintType.Hidden, boat_count: 0, boat_count_type: HintType.Hidden },
        { water_count: 2, water_count_type: HintType.Hidden, boat_count: 0, boat_count_type: HintType.Hidden }
      ],
      col_hints: [
        { water_count: 2, water_count_type: HintType.Hidden, boat_count: 0, boat_count_type: HintType.Hidden },
        { water_count: 2, water_count_type: HintType.Hidden, boat_count: 0, boat_count_type: HintType.Hidden }
      ],
      wall_bottom: [[false, false]],
      wall_right: [[false], [false]],
      grid_hints: { total_water: 4, total_boats: 0, expected_aquariums: {} }
    };
    
    expect(isLevelComplete(gridData as any)).toBe(true);
  });

  it('should be complete when all hints are satisfied even if cells are Nothing (airs not required)', () => {
    const gridData = {
      cells: [
        [
          { c_left: Content.Water, c_right: Content.Water, type: CellType.Single },
          { c_left: Content.Nothing, c_right: Content.Nothing, type: CellType.Single }
        ]
      ],
      row_hints: [{ water_count: 1, water_count_type: HintType.Hidden, boat_count: 0, boat_count_type: HintType.Hidden }],
      col_hints: [
        { water_count: 1, water_count_type: HintType.Hidden, boat_count: 0, boat_count_type: HintType.Hidden },
        { water_count: 0, water_count_type: HintType.Hidden, boat_count: 0, boat_count_type: HintType.Hidden }
      ],
      wall_bottom: [],
      wall_right: [[false]],
      grid_hints: { total_water: 1, total_boats: 0, expected_aquariums: {} }
    };
    
    // Complete because all hints are satisfied (airs are not required)
    expect(isLevelComplete(gridData as any)).toBe(true);
  });

  it('should fail if any hint is unsatisfied', () => {
    const gridData = {
      cells: [
        [
          { c_left: Content.Water, c_right: Content.Water, type: CellType.Single },
          { c_left: Content.Water, c_right: Content.Water, type: CellType.Single }
        ]
      ],
      row_hints: [{ water_count: 1, water_count_type: HintType.Hidden, boat_count: 0, boat_count_type: HintType.Hidden }],
      col_hints: [
        { water_count: 1, water_count_type: HintType.Hidden, boat_count: 0, boat_count_type: HintType.Hidden },
        { water_count: 0, water_count_type: HintType.Hidden, boat_count: 0, boat_count_type: HintType.Hidden }
      ],
      wall_bottom: [],
      wall_right: [[false]],
      grid_hints: { total_water: 1, total_boats: 0, expected_aquariums: {} }
    };
    
    // Fails because water count is 2 but hints expect 1 and 0
    expect(isLevelComplete(gridData as any)).toBe(false);
  });

  it('should validate aquariums and boats correctly', () => {
    // 2x2 grid, 1 boat, 3 water, all connected -> aquarium of size 4 with 1 boat
    const gridData = {
      cells: [
        [
          { c_left: Content.Boat, c_right: Content.Boat, type: CellType.Single },
          { c_left: Content.Water, c_right: Content.Water, type: CellType.Single }
        ],
        [
          { c_left: Content.Water, c_right: Content.Water, type: CellType.Single },
          { c_left: Content.Water, c_right: Content.Water, type: CellType.Single }
        ]
      ],
      row_hints: [
        { water_count: 2, water_count_type: HintType.Hidden, boat_count: 1, boat_count_type: HintType.Hidden },
        { water_count: 2, water_count_type: HintType.Hidden, boat_count: 0, boat_count_type: HintType.Hidden }
      ],
      col_hints: [
        { water_count: 2, water_count_type: HintType.Hidden, boat_count: 1, boat_count_type: HintType.Hidden },
        { water_count: 2, water_count_type: HintType.Hidden, boat_count: 0, boat_count_type: HintType.Hidden }
      ],
      wall_bottom: [[false, false]],
      wall_right: [[false], [false]],
      grid_hints: { total_water: 4, total_boats: 1, expected_aquariums: { "4": 1 } }
    };
    
    expect(isLevelComplete(gridData as any)).toBe(true);
  });
  
  it('should fail if aquariums sizes do not match', () => {
    // 2x2 grid, 1 boat, 3 water, separated by a wall into size 1 and size 3
    const gridData = {
      cells: [
        [
          { c_left: Content.Boat, c_right: Content.Boat, type: CellType.Single }, // Boat isolated
          { c_left: Content.Water, c_right: Content.Water, type: CellType.Single }
        ],
        [
          { c_left: Content.Water, c_right: Content.Water, type: CellType.Single },
          { c_left: Content.Water, c_right: Content.Water, type: CellType.Single }
        ]
      ],
      row_hints: [
        { water_count: 2, water_count_type: HintType.Hidden, boat_count: 1, boat_count_type: HintType.Hidden },
        { water_count: 2, water_count_type: HintType.Hidden, boat_count: 0, boat_count_type: HintType.Hidden }
      ],
      col_hints: [
        { water_count: 2, water_count_type: HintType.Hidden, boat_count: 1, boat_count_type: HintType.Hidden },
        { water_count: 2, water_count_type: HintType.Hidden, boat_count: 0, boat_count_type: HintType.Hidden }
      ],
      wall_bottom: [[true, false]], // Boat is walled off from below
      wall_right: [[true], [false]], // Boat is walled off from right
      // The expected says we should have one aquarium of size 4
      grid_hints: { total_water: 4, total_boats: 1, expected_aquariums: { "4": 1 } }
    };
    
    expect(isLevelComplete(gridData as any)).toBe(false);
  });

  it('should calculate aquarium sizes correctly across diagonal cells', () => {
    // 2x2 grid with IncDiag (/) at (0,0)
    // TL has Water (c_left: Water)
    // BR has NoWater (c_right: NoWater)
    // (0,1) has Water
    // (1,0) has NoWater
    // (1,1) has Water
    const gridData = {
      cells: [
        [
          { c_left: Content.Water, c_right: Content.NoWater, type: CellType.IncDiag },
          { c_left: Content.Water, c_right: Content.Water, type: CellType.Single }
        ],
        [
          { c_left: Content.NoWater, c_right: Content.NoWater, type: CellType.Single },
          { c_left: Content.Water, c_right: Content.Water, type: CellType.Single }
        ]
      ],
      row_hints: [
        { water_count: 1.5, water_count_type: HintType.Hidden, boat_count: 0, boat_count_type: HintType.Hidden },
        { water_count: 1, water_count_type: HintType.Hidden, boat_count: 0, boat_count_type: HintType.Hidden }
      ],
      col_hints: [
        { water_count: 0.5, water_count_type: HintType.Hidden, boat_count: 0, boat_count_type: HintType.Hidden },
        { water_count: 2, water_count_type: HintType.Hidden, boat_count: 0, boat_count_type: HintType.Hidden }
      ],
      wall_bottom: [[false, false]],
      wall_right: [[false], [false]],
      grid_hints: { total_water: 2.5, total_boats: 0, expected_aquariums: { "0.5": 1, "2": 1 } }
    };

    expect(isLevelComplete(gridData as any)).toBe(true);
  });
});
