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

  const rawGridHints = data["grid_data"]?.[ExportFields.grid_hints] ?? data["grid_data"]?.["16"] ?? data["grid_hints"] ?? {};
  const totalWater = rawGridHints[ExportFields.total_water] ?? rawGridHints["8"] ?? data.grid_data?.["8"] ?? -1;
  const totalBoats = rawGridHints[ExportFields.total_boats] ?? rawGridHints["9"] ?? data.grid_data?.["9"] ?? -1;
  const expectedAquariums = rawGridHints[ExportFields.expected_aquariums] ?? rawGridHints["10"] ?? data.grid_data?.["10"] ?? {};

  return {
    version,
    cells,
    cell_hints: [],
    row_hints: rowHints,
    col_hints: colHints,
    wall_bottom: wallBottom,
    wall_right: wallRight,
    grid_hints: { 
      total_water: totalWater, 
      total_boats: totalBoats, 
      expected_aquariums: expectedAquariums 
    },
    full_name: data.full_name
  };
}

export function countWaterCol(gridData: GridModelData, c: number) {
  let count = 0;
  for (let r = 0; r < gridData.cells.length; r++) {
    const cell = gridData.cells[r][c];
    const isWaterLeft = cell.c_left === Content.Water || cell.c_left === Content.Boat;
    const isWaterRight = cell.c_right === Content.Water || cell.c_right === Content.Boat;
    
    if (isWaterLeft) count += 0.5;
    if (cell.type === CellType.Single && isWaterLeft) count += 0.5;
    else if (cell.type !== CellType.Single && isWaterRight) count += 0.5;
  }
  return count;
}

export function countWaterRow(gridData: GridModelData, r: number) {
  let count = 0;
  for (let c = 0; c < gridData.cells[r].length; c++) {
    const cell = gridData.cells[r][c];
    const isWaterLeft = cell.c_left === Content.Water || cell.c_left === Content.Boat;
    const isWaterRight = cell.c_right === Content.Water || cell.c_right === Content.Boat;
    
    if (isWaterLeft) count += 0.5;
    if (cell.type === CellType.Single && isWaterLeft) count += 0.5;
    else if (cell.type !== CellType.Single && isWaterRight) count += 0.5;
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

export function rowBools(gridData: GridModelData, r: number, content: Content): boolean[] {
  const arr: boolean[] = [];
  for (let c = 0; c < gridData.cells[r].length; c++) {
    const cell = gridData.cells[r][c];
    const hasLeft = cell.c_left === content || (content === Content.Water && cell.c_left === Content.Boat);
    const hasRight = cell.c_right === content || (content === Content.Water && cell.c_right === Content.Boat);
    if (cell.type === CellType.Single) {
      arr.push(hasLeft);
      arr.push(hasRight);
    } else {
      arr.push(hasLeft);
      arr.push(hasRight);
    }
  }
  return arr;
}

export function colBools(gridData: GridModelData, c: number, content: Content): boolean[] {
  const arr: boolean[] = [];
  for (let r = 0; r < gridData.cells.length; r++) {
    const cell = gridData.cells[r][c];
    const hasLeft = cell.c_left === content || (content === Content.Water && cell.c_left === Content.Boat);
    const hasRight = cell.c_right === content || (content === Content.Water && cell.c_right === Content.Boat);
    
    if (cell.type === CellType.Single) {
      arr.push(hasLeft);
      arr.push(hasRight);
    } else {
      if (cell.type === CellType.IncDiag) { // /
        arr.push(hasLeft);
        arr.push(hasRight);
      } else if (cell.type === CellType.DecDiag) { // \
        arr.push(hasRight);
        arr.push(hasLeft);
      }
    }
  }
  return arr;
}

export function hintTypeOk(hint: HintType, arr: boolean[]): boolean {
  if (hint === HintType.Hidden) return true;
  return isTogether(arr) === hint;
}

export function getAquariums(gridData: GridModelData): { size: number, boats: number }[] {
  const rows = gridData.cells.length;
  const cols = rows > 0 ? gridData.cells[0].length : 0;
  if (rows === 0 || cols === 0) return [];
  
  const visited = new Set<string>();
  const aquariums: { size: number, boats: number }[] = [];
  
  function isBlock(r: number, c: number, corner: Corner): boolean {
    const cell = gridData.cells[r][c];
    if (cell.type === CellType.Single) {
      return cell.c_left === Content.Block || cell.c_right === Content.Block;
    }
    if (cell.type === CellType.IncDiag) {
      return corner === Corner.TopLeft ? cell.c_left === Content.Block : cell.c_right === Content.Block;
    }
    if (cell.type === CellType.DecDiag) {
      return corner === Corner.BottomLeft ? cell.c_left === Content.Block : cell.c_right === Content.Block;
    }
    return false;
  }
  
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      const cell = gridData.cells[r][c];
      let startCorners: Corner[] = [];
      if (cell.type === CellType.Single) {
        startCorners = [Corner.TopLeft];
      } else if (cell.type === CellType.IncDiag) {
        startCorners = [Corner.TopLeft, Corner.BottomRight];
      } else if (cell.type === CellType.DecDiag) {
        startCorners = [Corner.BottomLeft, Corner.TopRight];
      }
      
      for (const startCorner of startCorners) {
        const startId = `${r},${c},${startCorner}`;
        if (visited.has(startId)) continue;
        if (isBlock(r, c, startCorner)) {
          visited.add(startId);
          continue;
        }
        
        let aquariumWater = 0;
        let aquariumBoats = 0;
        const queue: { r: number, c: number, corner: Corner }[] = [{ r, c, corner: startCorner }];
        visited.add(startId);
        
        while (queue.length > 0) {
          const curr = queue.shift()!;
          const currCell = gridData.cells[curr.r][curr.c];
          
          if (currCell.type === CellType.Single) {
            if (currCell.c_left === Content.Water || currCell.c_left === Content.Boat) aquariumWater += 0.5;
            if (currCell.c_right === Content.Water || currCell.c_right === Content.Boat) aquariumWater += 0.5;
            if (currCell.c_left === Content.Boat || currCell.c_right === Content.Boat) aquariumBoats += 1;
          } else if (currCell.type === CellType.IncDiag) {
            const content = curr.corner === Corner.TopLeft ? currCell.c_left : currCell.c_right;
            if (content === Content.Water || content === Content.Boat) aquariumWater += 0.5;
            if (content === Content.Boat) aquariumBoats += 1;
          } else if (currCell.type === CellType.DecDiag) {
            const content = curr.corner === Corner.BottomLeft ? currCell.c_left : currCell.c_right;
            if (content === Content.Water || content === Content.Boat) aquariumWater += 0.5;
            if (content === Content.Boat) aquariumBoats += 1;
          }
          
          const isLeft = curr.corner === Corner.TopLeft || curr.corner === Corner.BottomLeft;
          const isTop = curr.corner === Corner.TopLeft || curr.corner === Corner.TopRight;
          
          // 1. Try Left
          if (!(currCell.type !== CellType.Single && !isLeft)) {
            if (curr.c > 0 && !gridData.wall_right[curr.r]?.[curr.c - 1]) {
              const nr = curr.r;
              const nc = curr.c - 1;
              const nCell = gridData.cells[nr][nc];
              let nCorner = Corner.TopLeft;
              if (nCell.type === CellType.IncDiag) nCorner = Corner.BottomRight;
              else if (nCell.type === CellType.DecDiag) nCorner = Corner.TopRight;
              
              const nid = `${nr},${nc},${nCorner}`;
              if (!visited.has(nid) && !isBlock(nr, nc, nCorner)) {
                visited.add(nid);
                queue.push({ r: nr, c: nc, corner: nCorner });
              }
            }
          }
          
          // 2. Try Right
          if (!(currCell.type !== CellType.Single && isLeft)) {
            if (curr.c < cols - 1 && !gridData.wall_right[curr.r]?.[curr.c]) {
              const nr = curr.r;
              const nc = curr.c + 1;
              const nCell = gridData.cells[nr][nc];
              let nCorner = Corner.TopLeft;
              if (nCell.type === CellType.IncDiag) nCorner = Corner.TopLeft;
              else if (nCell.type === CellType.DecDiag) nCorner = Corner.BottomLeft;
              
              const nid = `${nr},${nc},${nCorner}`;
              if (!visited.has(nid) && !isBlock(nr, nc, nCorner)) {
                visited.add(nid);
                queue.push({ r: nr, c: nc, corner: nCorner });
              }
            }
          }
          
          // 3. Try Down
          if (!(currCell.type !== CellType.Single && isTop)) {
            if (curr.r < rows - 1 && !gridData.wall_bottom[curr.r]?.[curr.c]) {
              const nr = curr.r + 1;
              const nc = curr.c;
              const nCell = gridData.cells[nr][nc];
              let nCorner = Corner.TopLeft;
              if (nCell.type === CellType.IncDiag) nCorner = Corner.TopLeft;
              else if (nCell.type === CellType.DecDiag) nCorner = Corner.TopRight;
              
              const nid = `${nr},${nc},${nCorner}`;
              if (!visited.has(nid) && !isBlock(nr, nc, nCorner)) {
                visited.add(nid);
                queue.push({ r: nr, c: nc, corner: nCorner });
              }
            }
          }
          
          // 4. Try Up
          if (!(currCell.type !== CellType.Single && !isTop)) {
            if (curr.r > 0 && !gridData.wall_bottom[curr.r - 1]?.[curr.c]) {
              const nr = curr.r - 1;
              const nc = curr.c;
              const nCell = gridData.cells[nr][nc];
              let nCorner = Corner.TopLeft;
              if (nCell.type === CellType.IncDiag) nCorner = Corner.BottomRight;
              else if (nCell.type === CellType.DecDiag) nCorner = Corner.BottomLeft;
              
              const nid = `${nr},${nc},${nCorner}`;
              if (!visited.has(nid) && !isBlock(nr, nc, nCorner)) {
                visited.add(nid);
                queue.push({ r: nr, c: nc, corner: nCorner });
              }
            }
          }
        }
        
        aquariums.push({ size: aquariumWater, boats: aquariumBoats });
      }
    }
  }
  
  return aquariums;
}

export function isLevelComplete(gridData: GridModelData): boolean {
  if (gridData.cells.length === 0) return false;
  
  // Rule 1: All cells must be filled (no Content.Nothing)
  for (let r = 0; r < gridData.cells.length; r++) {
    for (let c = 0; c < gridData.cells[r].length; c++) {
      const cell = gridData.cells[r][c];
      if (cell.type === CellType.Single) {
        if (cell.c_left === Content.Nothing) return false;
      } else {
        if (cell.c_left === Content.Nothing || cell.c_right === Content.Nothing) return false;
      }
    }
  }
  
  // Check hints
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
  
  // Check aquariums
  const expAquariums = gridData.grid_hints.expected_aquariums;
  if (expAquariums && Object.keys(expAquariums).length > 0) {
    const foundAquariums = getAquariums(gridData);
    
    for (const sizeKey of Object.keys(expAquariums)) {
      const expCount = expAquariums[sizeKey];
      if (expCount === -1) continue;
      const parsedSize = parseFloat(sizeKey);
      
      let actualCount = 0;
      for (const aq of foundAquariums) {
        if (Math.abs(aq.size - parsedSize) < 0.01) {
          actualCount++;
        }
      }
      if (actualCount !== expCount) return false;
    }
  }
  
  if (gridData.grid_hints.total_boats > 0) {
    const foundAquariums = getAquariums(gridData);
    for (const aq of foundAquariums) {
      if (aq.size > 0 && aq.boats !== 1) return false;
    }
  }
  
  return true;
}
