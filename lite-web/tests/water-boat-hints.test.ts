import { describe, it, expect } from 'vitest';
import {
  Content,
  CellType,
  HintType,
  countWaterRow,
  countWaterCol,
  countBoatRow,
  countBoatCol,
  rowBools,
  colBools,
  isTogether,
  hintTypeOk,
  isLevelComplete,
  parseGridData,
  getAquariums
} from '../src/model/GridData';
import type { GridModelData } from '../src/model/GridData';
import { GridImpl } from '../src/engine/GridImpl';
import { E } from '../src/engine/E';

describe('Water and Boat Hint Satisfiability & Level 04/05', () => {
  // Level 04/05 raw definition from project/database/levels/04/05.json
  const LEVEL_04_05_RAW = {
    full_name: "LEVEL_04_05",
    grid_data: {
      "0": 1,
      "11": [
        { "4": 4, "5": 1, "6": -1, "7": 0 },   // Row 0: {4} Together
        { "4": 3.5, "5": 0, "6": -1, "7": 0 }, // Row 1: 3.5
        { "4": -1, "5": 0, "6": -1, "7": 0 }   // Row 2
      ],
      "12": [
        { "4": -1, "5": 1, "6": -1, "7": 0 }, // Col 0: {?}
        { "4": -1, "5": 1, "6": -1, "7": 0 }, // Col 1: {?}
        { "4": -1, "5": 0, "6": -1, "7": 0 },
        { "4": -1, "5": 0, "6": -1, "7": 0 },
        { "4": -1, "5": 0, "6": -1, "7": 0 },
        { "4": -1, "5": 2, "6": -1, "7": 0 }  // Col 5: -?-
      ],
      "13": [
        // Solution row 0: DecDiag Water, Water, Water, Water, Air, Boat
        [
          { "1": 1, "2": 1, "3": 10 },
          { "1": 1, "2": 1, "3": 11 },
          { "1": 1, "2": 1, "3": 11 },
          { "1": 1, "2": 1, "3": 11 },
          { "1": 0, "2": 0, "3": 11 },
          { "1": 4, "2": 4, "3": 11 }
        ],
        // Solution row 1: Water, DecDiag Water, Water, Boat, IncDiag Air, DecDiag Air/Water
        [
          { "1": 1, "2": 1, "3": 11 },
          { "1": 1, "2": 1, "3": 10 },
          { "1": 1, "2": 1, "3": 11 },
          { "1": 4, "2": 4, "3": 11 },
          { "1": 0, "2": 0, "3": 9 },
          { "1": 0, "2": 1, "3": 10 }
        ],
        // Solution row 2: Water, Water, Water, IncDiag Water, Water, Water
        [
          { "1": 1, "2": 1, "3": 11 },
          { "1": 1, "2": 1, "3": 11 },
          { "1": 1, "2": 1, "3": 11 },
          { "1": 1, "2": 1, "3": 9 },
          { "1": 1, "2": 1, "3": 11 },
          { "1": 1, "2": 1, "3": 11 }
        ]
      ],
      "14": [[0, 0, 1, 1, 0, 0], [0, 1, 0, 0, 0, 0]],
      "15": [[0, 1, 0, 1, 0], [0, 0, 1, 1, 0], [1, 0, 1, 0, 0]],
      "16": { "8": -1, "9": 2, "10": {} } // total_boats: 2
    },
    version: 1
  };

  it('Level 04/05 Row 0: hint {4} remains satisfied and green when adding a boat', () => {
    // Row 0 has hint {4}: water_count = 4, water_count_type = Together
    const rowCells = [
      { c_left: Content.Water, c_right: Content.Water, type: CellType.DecDiag }, // 1.0 water
      { c_left: Content.Water, c_right: Content.Water, type: CellType.Single },  // 1.0 water
      { c_left: Content.Water, c_right: Content.Water, type: CellType.Single },  // 1.0 water
      { c_left: Content.Water, c_right: Content.Water, type: CellType.Single },  // 1.0 water
      { c_left: Content.Nothing, c_right: Content.Nothing, type: CellType.Single }, // 0 water
      { c_left: Content.Nothing, c_right: Content.Nothing, type: CellType.Single }  // 0 water (initially empty)
    ];

    const gridData: GridModelData = {
      cells: [rowCells],
      row_hints: [{ water_count: 4, water_count_type: HintType.Together, boat_count: -1, boat_count_type: HintType.Hidden }],
      col_hints: Array(6).fill({ water_count: -1, water_count_type: HintType.Hidden, boat_count: -1, boat_count_type: HintType.Hidden }),
      wall_bottom: [Array(6).fill(false)],
      wall_right: [Array(5).fill(false)],
      grid_hints: { total_water: -1, total_boats: 1, expected_aquariums: {} }
    };

    // Before boat is placed: 4 waters, together
    expect(countWaterRow(gridData, 0)).toBe(4);
    expect(countBoatRow(gridData, 0)).toBe(0);
    const wBoolsBefore = rowBools(gridData, 0, Content.Water);
    expect(isTogether(wBoolsBefore)).toBe(HintType.Together);
    expect(hintTypeOk(HintType.Together, wBoolsBefore)).toBe(true);

    // Now place a boat at col 5
    rowCells[5] = { c_left: Content.Boat, c_right: Content.Boat, type: CellType.Single };

    // AFTER boat is placed:
    // 1. Water count must STILL be 4 (not 5!)
    expect(countWaterRow(gridData, 0)).toBe(4);
    // 2. Boat count must be 1
    expect(countBoatRow(gridData, 0)).toBe(1);
    // 3. Water row bools must NOT count the boat as water
    const wBoolsAfter = rowBools(gridData, 0, Content.Water);
    // Col 4 (air) and Col 5 (boat) are both false for water
    expect(wBoolsAfter[8]).toBe(false);  // cell 4 left
    expect(wBoolsAfter[9]).toBe(false);  // cell 4 right
    expect(wBoolsAfter[10]).toBe(false); // cell 5 left (boat)
    expect(wBoolsAfter[11]).toBe(false); // cell 5 right (boat)
    // 4. Togetherness of water must STILL be Together (not broken/separated into red hint-over)
    expect(isTogether(wBoolsAfter)).toBe(HintType.Together);
    expect(hintTypeOk(HintType.Together, wBoolsAfter)).toBe(true);
  });

  it('solves full Level 04/05 and verifies all hints satisfied', () => {
    const parsed = parseGridData(LEVEL_04_05_RAW);

    // Check row 0: {4}
    expect(countWaterRow(parsed, 0)).toBe(4);
    expect(isTogether(rowBools(parsed, 0, Content.Water))).toBe(HintType.Together);
    expect(parsed.row_hints[0].water_count).toBe(4);
    expect(parsed.row_hints[0].water_count_type).toBe(HintType.Together);

    // Check row 1: 3.5
    expect(countWaterRow(parsed, 1)).toBe(3.5);
    expect(parsed.row_hints[1].water_count).toBe(3.5);

    // Check boats
    expect(countBoatRow(parsed, 0)).toBe(1); // boat at (0, 5)
    expect(countBoatRow(parsed, 1)).toBe(1); // boat at (1, 3)
    expect(countBoatRow(parsed, 2)).toBe(0);
    const totalBoats = countBoatRow(parsed, 0) + countBoatRow(parsed, 1) + countBoatRow(parsed, 2);
    expect(totalBoats).toBe(2);
    expect(parsed.grid_hints.total_boats).toBe(2);

    // Check col 0: Together {?}
    expect(isTogether(colBools(parsed, 0, Content.Water))).toBe(HintType.Together);

    // Check col 1: Together {?}
    expect(isTogether(colBools(parsed, 1, Content.Water))).toBe(HintType.Together);

    // Check col 5: Separated -?-
    expect(isTogether(colBools(parsed, 5, Content.Water))).toBe(HintType.Separated);

    // Level must be complete!
    expect(isLevelComplete(parsed)).toBe(true);
  });

  it('simulate click sequence for Level 04/05', () => {
    const parsed = parseGridData(LEVEL_04_05_RAW);
    for (let r = 0; r < parsed.cells.length; r++) {
      for (let c = 0; c < parsed.cells[r].length; c++) {
        if (parsed.cells[r][c].c_left !== Content.Block) parsed.cells[r][c].c_left = Content.Nothing;
        if (parsed.cells[r][c].c_right !== Content.Block) parsed.cells[r][c].c_right = Content.Nothing;
      }
    }
    const engine = GridImpl.load_from_grid_data(parsed);

    // Let's click water:
    // Left container: (2,0), (2,1), (1,0), (1,1), (0,0), (0,1)
    engine.get_cell(2, 0).put_water(E.Corner.TopLeft);
    engine.get_cell(2, 1).put_water(E.Corner.TopLeft);
    engine.get_cell(1, 0).put_water(E.Corner.TopLeft);
    engine.get_cell(1, 1).put_water(E.Corner.TopLeft);
    engine.get_cell(0, 0).put_water(E.Corner.BottomLeft);
    engine.get_cell(0, 0).put_water(E.Corner.TopRight);
    engine.get_cell(0, 1).put_water(E.Corner.TopLeft);

    // Middle container: (2,2), (1,2), (0,2), (0,3)
    engine.get_cell(2, 2).put_water(E.Corner.TopLeft);
    engine.get_cell(1, 2).put_water(E.Corner.TopLeft);
    engine.get_cell(0, 2).put_water(E.Corner.TopLeft);
    engine.get_cell(0, 3).put_water(E.Corner.TopLeft);

    const gd = engine.to_grid_data();
    expect(countWaterRow(gd, 0)).toBe(4);
    expect(isTogether(rowBools(gd, 0, Content.Water))).toBe(HintType.Together);

    // Now place boat at (0, 5)
    engine.get_cell(0, 5).put_boat();
    const gdBoat = engine.to_grid_data();
    expect(countWaterRow(gdBoat, 0)).toBe(4);
    expect(isTogether(rowBools(gdBoat, 0, Content.Water))).toBe(HintType.Together);
    expect(countBoatRow(gdBoat, 0)).toBe(1);

    // Complete the rest of the level:
    // Right container at bottom: (2, 3), (2, 4), (2, 5)
    engine.get_cell(2, 3).put_water(E.Corner.BottomRight);
    engine.get_cell(2, 4).put_water(E.Corner.TopLeft);
    engine.get_cell(2, 5).put_water(E.Corner.TopLeft);
    // (1, 5) dec diag right half
    engine.get_cell(1, 5).put_water(E.Corner.TopRight);
    // (1, 3) boat
    engine.get_cell(1, 3).put_boat();

    const gdFull = engine.to_grid_data();
    expect(isLevelComplete(gdFull)).toBe(true);
  });

  it('water hints and boat hints are strictly independent', () => {
    // 1 row with 4 cells: [Water, Air, Water, Boat]
    const gridData: GridModelData = {
      cells: [[
        { c_left: Content.Water, c_right: Content.Water, type: CellType.Single },
        { c_left: Content.Nothing, c_right: Content.Nothing, type: CellType.Single },
        { c_left: Content.Water, c_right: Content.Water, type: CellType.Single },
        { c_left: Content.Boat, c_right: Content.Boat, type: CellType.Single }
      ]],
      row_hints: [
        { water_count: 2, water_count_type: HintType.Separated, boat_count: 1, boat_count_type: HintType.Together }
      ],
      col_hints: Array(4).fill({ water_count: -1, water_count_type: HintType.Hidden, boat_count: -1, boat_count_type: HintType.Hidden }),
      wall_bottom: [[false, false, false, false]],
      wall_right: [[false, false, false]],
      grid_hints: { total_water: 2, total_boats: 1, expected_aquariums: {} }
    };

    // Water count is 2, not 3
    expect(countWaterRow(gridData, 0)).toBe(2);
    // Boat count is 1, not 3
    expect(countBoatRow(gridData, 0)).toBe(1);

    // Water is Separated by the air cell at index 1
    const wBools = rowBools(gridData, 0, Content.Water);
    expect(isTogether(wBools)).toBe(HintType.Separated);

    // Boat is Together (only at cell 3)
    const bBools = rowBools(gridData, 0, Content.Boat);
    expect(isTogether(bBools)).toBe(HintType.Together);

    expect(isLevelComplete(gridData)).toBe(true);
  });

  it('boat does not bridge disconnected water cells', () => {
    // [Water, Boat, Water]
    // The water is separated by the boat. The boat should NOT make water "Together".
    const gridData: GridModelData = {
      cells: [[
        { c_left: Content.Water, c_right: Content.Water, type: CellType.Single },
        { c_left: Content.Boat, c_right: Content.Boat, type: CellType.Single },
        { c_left: Content.Water, c_right: Content.Water, type: CellType.Single }
      ]],
      row_hints: [
        { water_count: 2, water_count_type: HintType.Separated, boat_count: 1, boat_count_type: HintType.Hidden }
      ],
      col_hints: Array(3).fill({ water_count: -1, water_count_type: HintType.Hidden, boat_count: -1, boat_count_type: HintType.Hidden }),
      wall_bottom: [[false, false, false]],
      wall_right: [[false, false]],
      grid_hints: { total_water: 2, total_boats: 1, expected_aquariums: {} }
    };

    expect(countWaterRow(gridData, 0)).toBe(2);
    expect(isTogether(rowBools(gridData, 0, Content.Water))).toBe(HintType.Separated);
    expect(isLevelComplete(gridData)).toBe(true);
  });

  it('column water count and column water togetherness are independent of boats', () => {
    // 3 rows x 1 col:
    // Row 0: Water
    // Row 1: Boat
    // Row 2: Water
    const gridData: GridModelData = {
      cells: [
        [{ c_left: Content.Water, c_right: Content.Water, type: CellType.Single }],
        [{ c_left: Content.Boat, c_right: Content.Boat, type: CellType.Single }],
        [{ c_left: Content.Water, c_right: Content.Water, type: CellType.Single }]
      ],
      row_hints: Array(3).fill({ water_count: -1, water_count_type: HintType.Hidden, boat_count: -1, boat_count_type: HintType.Hidden }),
      col_hints: [
        { water_count: 2, water_count_type: HintType.Separated, boat_count: 1, boat_count_type: HintType.Together }
      ],
      wall_bottom: [[false], [false]],
      wall_right: [[]],
      grid_hints: { total_water: 2, total_boats: 1, expected_aquariums: {} }
    };

    expect(countWaterCol(gridData, 0)).toBe(2);
    expect(countBoatCol(gridData, 0)).toBe(1);
    expect(isTogether(colBools(gridData, 0, Content.Water))).toBe(HintType.Separated);
    expect(isTogether(colBools(gridData, 0, Content.Boat))).toBe(HintType.Together);
    expect(isLevelComplete(gridData)).toBe(true);
  });

  it('Level 05/01 includes 0-water aquarium hint in expected_aquariums and satisfies when empty count is 0', () => {
    const rawData = {
      full_name: "LEVEL_05_01",
      grid_data: {
        "0": 1,
        "11": [{ "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }],
        "12": [{ "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }],
        "13": [
          [{ "1": 1, "2": 1, "3": 10 }, { "1": 1, "2": 1, "3": 9 }, { "1": 0, "2": 0, "3": 11 }, { "1": 0, "2": 0, "3": 11 }, { "1": 0, "2": 0, "3": 11 }],
          [{ "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 3, "3": 9 }, { "1": 1, "2": 1, "3": 11 }],
          [{ "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }]
        ],
        "14": [[0, 0, 0, 0, 0], [1, 1, 1, 0, 1]],
        "15": [[0, 1, 0, 0], [0, 1, 0, 1], [0, 0, 0, 0]],
        "16": { "8": -1, "9": 0, "10": { "0": 0, "2.5": 1, "3": 1 } }
      },
      version: 1
    };
    const parsed = parseGridData(rawData);
    expect(parsed.grid_hints.expected_aquariums).toHaveProperty('0');
    expect(parsed.grid_hints.expected_aquariums['0']).toBe(0);
    expect(parsed.grid_hints.expected_aquariums['2.5']).toBe(1);
    expect(parsed.grid_hints.expected_aquariums['3']).toBe(1);

    const aqEntries = Object.entries(parsed.grid_hints.expected_aquariums)
      .filter(([_, v]) => v !== -1 && v >= 0)
      .sort(([a], [b]) => parseFloat(a) - parseFloat(b));

    expect(aqEntries).toEqual([
      ['0', 0],
      ['2.5', 1],
      ['3', 1]
    ]);

    // Solved level has 0 aquariums with 0 water
    const aquariumsSolved = getAquariums(parsed);
    const zeroWaterAqs = aquariumsSolved.filter(aq => Math.abs(aq.size - 0) < 0.01);
    expect(zeroWaterAqs.length).toBe(0);
    expect(isLevelComplete(parsed)).toBe(true);
  });
});
