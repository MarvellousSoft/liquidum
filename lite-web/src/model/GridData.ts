export const SAVE_VERSION = 2;

export enum ExportFields {
  version = 0,
  c_left = 1,
  c_right = 2,
  cell_type = 3,
  water_count = 4,
  water_count_type = 5,
  boat_count = 6,
  boat_count_type = 7,
  total_water = 8,
  total_boats = 9,
  expected_aquariums = 10,
  row_hints = 11,
  col_hints = 12,
  cells = 13,
  wall_bottom = 14,
  wall_right = 15,
  grid_hints = 16,
  cell_hints = 17,
  adj_water_count = 18,
  adj_water_count_type = 19
}

export enum Content {
  Nothing = 0,
  Water = 1,
  NoWater = 2,
  Block = 3,
  Boat = 4,
  NoBoat = 5,
  NoBoatWater = 6
}

export enum CellType {
  IncDiag = 9,
  DecDiag = 10,
  Single = 11
}

export enum Corner {
  TopLeft = 5,
  TopRight = 6,
  BottomRight = 7,
  BottomLeft = 8
}

export enum HintType {
  Hidden = 0,
  Together = 1,
  Separated = 2,
  Zero = 3
}

export interface PureCell {
  c_left: Content;
  c_right: Content;
  type: CellType;
}

export interface LineHint {
  water_count: number;
  water_count_type: HintType;
  boat_count: number;
  boat_count_type: HintType;
}

export interface CellHints {
  adj_water_count: number;
  adj_water_count_type: HintType;
}

export interface GridHints {
  total_water: number;
  total_boats: number;
  expected_aquariums: Record<string, number>;
}

export interface GridModelData {
  version: number;
  cells: PureCell[][];
  cell_hints: (CellHints | null)[][];
  row_hints: LineHint[];
  col_hints: LineHint[];
  wall_bottom: boolean[][];
  wall_right: boolean[][];
  grid_hints: GridHints;
  full_name?: string;
}

export function parsePureCell(data: Record<string, any>): PureCell {
  return {
    c_left: data[ExportFields.c_left] as Content,
    c_right: data[ExportFields.c_right] as Content,
    type: data[ExportFields.cell_type] as CellType,
  };
}

export function parseGridData(data: any): GridModelData {
  const version = data[ExportFields.version] ?? data["version"];
  
  const rawCells = data[ExportFields.cells] ?? data["grid_data"]?.[ExportFields.cells];
  const cells: PureCell[][] = [];
  
  if (rawCells) {
    const rowKeys = Object.keys(rawCells).sort((a, b) => parseInt(a) - parseInt(b));
    for (const rk of rowKeys) {
      const row = rawCells[rk];
      const parsedRow: PureCell[] = [];
      const colKeys = Object.keys(row).sort((a, b) => parseInt(a) - parseInt(b));
      for (const ck of colKeys) {
        parsedRow.push(parsePureCell(row[ck]));
      }
      cells.push(parsedRow);
    }
  }

  const parseLineHint = (raw: any): LineHint => ({
    water_count: raw[ExportFields.water_count] ?? raw["4"] ?? -1,
    water_count_type: raw[ExportFields.water_count_type] ?? raw["5"] ?? HintType.Hidden,
    boat_count: raw[ExportFields.boat_count] ?? raw["6"] ?? -1,
    boat_count_type: raw[ExportFields.boat_count_type] ?? raw["7"] ?? HintType.Hidden,
  });

  const rowHints: LineHint[] = [];
  const rawRowHints = data["grid_data"]?.[ExportFields.row_hints];
  if (rawRowHints) {
    for (const key of Object.keys(rawRowHints).sort((a, b) => parseInt(a) - parseInt(b))) {
      rowHints.push(parseLineHint(rawRowHints[key]));
    }
  }

  const colHints: LineHint[] = [];
  const rawColHints = data["grid_data"]?.[ExportFields.col_hints];
  if (rawColHints) {
    for (const key of Object.keys(rawColHints).sort((a, b) => parseInt(a) - parseInt(b))) {
      colHints.push(parseLineHint(rawColHints[key]));
    }
  }

  const parseBoolMatrix = (raw: any): boolean[][] => {
    if (!raw) return [];
    const mat: boolean[][] = [];
    for (const rk of Object.keys(raw).sort((a, b) => parseInt(a) - parseInt(b))) {
      const row: boolean[] = [];
      for (const ck of Object.keys(raw[rk]).sort((a, b) => parseInt(a) - parseInt(b))) {
        row.push(raw[rk][ck] !== 0 && raw[rk][ck] !== false);
      }
      mat.push(row);
    }
    return mat;
  };

  const wallBottom = parseBoolMatrix(data["grid_data"]?.[ExportFields.wall_bottom]);
  const wallRight = parseBoolMatrix(data["grid_data"]?.[ExportFields.wall_right]);

  return {
    version,
    cells,
    cell_hints: [],
    row_hints: rowHints,
    col_hints: colHints,
    wall_bottom: wallBottom,
    wall_right: wallRight,
    grid_hints: { total_water: data.grid_data?.["8"] ?? -1, total_boats: data.grid_data?.["9"] ?? 0, expected_aquariums: data.grid_data?.["10"] ?? {} },
    full_name: data.full_name
  };
}

export function countWaterCol(gridData: GridModelData, c: number) {
  let count = 0;
  for (let r = 0; r < gridData.cells.length; r++) {
    const cell = gridData.cells[r][c];
    if (cell.c_left === Content.Water) count += 0.5;
    if (cell.type === CellType.Single && cell.c_left === Content.Water) count += 0.5;
    else if (cell.type !== CellType.Single && cell.c_right === Content.Water) count += 0.5;
  }
  return count;
}

export function countWaterRow(gridData: GridModelData, r: number) {
  let count = 0;
  for (let c = 0; c < gridData.cells[r].length; c++) {
    const cell = gridData.cells[r][c];
    if (cell.c_left === Content.Water) count += 0.5;
    if (cell.type === CellType.Single && cell.c_left === Content.Water) count += 0.5;
    else if (cell.type !== CellType.Single && cell.c_right === Content.Water) count += 0.5;
  }
  return count;
}

export function countBoatCol(gridData: GridModelData, c: number) {
  let count = 0;
  for (let r = 0; r < gridData.cells.length; r++) {
    const cell = gridData.cells[r][c];
    if (cell.c_left === Content.Boat || cell.c_right === Content.Boat) count++;
  }
  return count;
}

export function countBoatRow(gridData: GridModelData, r: number) {
  let count = 0;
  for (let c = 0; c < gridData.cells[r].length; c++) {
    const cell = gridData.cells[r][c];
    if (cell.c_left === Content.Boat || cell.c_right === Content.Boat) count++;
  }
  return count;
}

export function isTogether(arr: boolean[]): HintType {
  let i = 0;
  while (i < arr.length && !arr[i]) i++;
  if (i === arr.length) return HintType.Zero;
  while (i < arr.length && arr[i]) i++;
  while (i < arr.length && !arr[i]) i++;
  return i === arr.length ? HintType.Together : HintType.Separated;
}

function rowBools(gridData: GridModelData, r: number, content: Content): boolean[] {
  const arr: boolean[] = [];
  for (let c = 0; c < gridData.cells[r].length; c++) {
    const cell = gridData.cells[r][c];
    if (cell.type === CellType.Single) {
      arr.push(cell.c_left === content);
      arr.push(cell.c_right === content);
    } else {
      arr.push(cell.c_left === content);
      arr.push(cell.c_right === content); // Note: Original game tracks top/bottom logic for columns too, left/right for rows
    }
  }
  return arr;
}

function colBools(gridData: GridModelData, c: number, content: Content): boolean[] {
  const arr: boolean[] = [];
  for (let r = 0; r < gridData.cells.length; r++) {
    const cell = gridData.cells[r][c];
    if (cell.type === CellType.Single) {
      arr.push(cell.c_left === content);
      arr.push(cell.c_right === content);
    } else {
      // In Godot it's _content_top and _content_bottom for colBools
      // For Single: same. For Diagonals: Top/Bottom
      // We'll simplify and just push left/right for now since web doesn't fully track top/bottom in purecell yet, 
      // but actually we know: TopLeft/TopRight is top.
      const isTopLeft = cell.c_left;
      const isBottomRight = cell.c_right;
      if (cell.type === CellType.IncDiag) { // /
        arr.push(isTopLeft === content);
        arr.push(isBottomRight === content);
      } else if (cell.type === CellType.DecDiag) { // \
        arr.push(cell.c_right === content); // TopRight
        arr.push(cell.c_left === content); // BottomLeft
      }
    }
  }
  return arr;
}

export function hintTypeOk(hint: HintType, arr: boolean[]): boolean {
  if (hint === HintType.Hidden) return true;
  return isTogether(arr) === hint;
}

export function isLevelComplete(gridData: GridModelData): boolean {
  if (gridData.cells.length === 0) return false;
  
  // Check if any hints are unsatisfied
  for (let r = 0; r < gridData.row_hints.length; r++) {
    const hint = gridData.row_hints[r];
    if (hint.water_count >= 0 && countWaterRow(gridData, r) !== hint.water_count) return false;
    if (hint.boat_count >= 0 && countBoatRow(gridData, r) !== hint.boat_count) return false;
    if (!hintTypeOk(hint.water_count_type, rowBools(gridData, r, Content.Water))) return false;
    if (!hintTypeOk(hint.boat_count_type, rowBools(gridData, r, Content.Boat))) return false;
  }
  for (let c = 0; c < gridData.col_hints.length; c++) {
    const hint = gridData.col_hints[c];
    if (hint.water_count >= 0 && countWaterCol(gridData, c) !== hint.water_count) return false;
    if (hint.boat_count >= 0 && countBoatCol(gridData, c) !== hint.boat_count) return false;
    if (!hintTypeOk(hint.water_count_type, colBools(gridData, c, Content.Water))) return false;
    if (!hintTypeOk(hint.boat_count_type, colBools(gridData, c, Content.Boat))) return false;
  }
  
  if (gridData.grid_hints.total_water >= 0) {
    let totalWater = 0;
    for (let r = 0; r < gridData.cells.length; r++) totalWater += countWaterRow(gridData, r);
    if (totalWater !== gridData.grid_hints.total_water) return false;
  }
  if (gridData.grid_hints.total_boats >= 0) {
    let totalBoats = 0;
    for (let r = 0; r < gridData.cells.length; r++) totalBoats += countBoatRow(gridData, r);
    if (totalBoats !== gridData.grid_hints.total_boats) return false;
  }
  
  return true;
}
