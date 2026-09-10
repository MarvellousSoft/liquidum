import { h } from 'preact';
import { Corner, Content, CellType, HintType, countWaterRow, countWaterCol, countBoatRow, countBoatCol, isTogether } from '../model/GridData';
import type { GridModelData } from '../model/GridData';
import { Cell } from './Cell';

interface GridProps {
  gridData: GridModelData;
  onCellPointerDown?: (row: number, col: number, corner: Corner, e: PointerEvent) => void;
  onCellPointerEnter?: (row: number, col: number, corner: Corner, e: PointerEvent) => void;
  onCellPointerUp?: (row: number, col: number, e: PointerEvent) => void;
}

export function Grid({ gridData, onCellPointerDown, onCellPointerEnter, onCellPointerUp }: GridProps) {
  const rows = gridData.cells.length;
  const cols = rows > 0 ? gridData.cells[0].length : 0;

  if (rows === 0 || cols === 0) return <div>Empty Grid</div>;

  const getHintColor = (current: number, target: number, isWater: boolean, targetType: HintType, bools: boolean[]) => {
    if (target < 0 && targetType === HintType.Hidden) return 'opacity-0';
    if (target < 0) {
      if (isTogether(bools) === targetType) return isWater ? 'text-[var(--cell-water)] font-bold' : 'text-white font-bold';
      return 'text-slate-400 font-bold';
    }
    
    const countOk = current === target;
    const typeOk = targetType === HintType.Hidden || isTogether(bools) === targetType;
    
    if (countOk && typeOk) return isWater ? 'text-[var(--cell-water)] font-bold' : 'text-white font-bold';
    if (current > target) return 'text-red-500 font-bold';
    return 'text-slate-400 font-bold';
  };
  
  const isBlockSide = (r: number, c: number, side: 'top' | 'bottom' | 'left' | 'right') => {
    if (r < 0 || r >= gridData.cells.length || c < 0 || c >= gridData.cells[r].length) return false;
    const cell = gridData.cells[r][c];
    if (cell.type === CellType.Single) return cell.c_left === Content.Block;
    if (cell.type === CellType.IncDiag) {
      if (side === 'top' || side === 'left') return cell.c_left === Content.Block;
      if (side === 'bottom' || side === 'right') return cell.c_right === Content.Block;
    }
    if (cell.type === CellType.DecDiag) {
      if (side === 'bottom' || side === 'left') return cell.c_left === Content.Block;
      if (side === 'top' || side === 'right') return cell.c_right === Content.Block;
    }
    return false;
  };
  
  const renderHint = (count: number, type: HintType, isWater: boolean) => {
    if (count >= 0) return `${isWater ? '' : '⛵'}${count}`;
    if (type === HintType.Together) return '{?}';
    if (type === HintType.Separated) return '-?-';
    if (type === HintType.Zero) return '0';
    return '';
  };

  return (
    <div class="inline-block relative">
      {/* Column Hints Header */}
      <div class="flex">
        {/* Empty top-left corner */}
        <div class="w-16 sm:w-20 md:w-24 flex-shrink-0"></div>
        {/* Column hints */}
        <div class="flex" style={{ width: `calc(${cols} * var(--cell-size, 3rem))` }}>
          {gridData.col_hints.map((hint, c) => {
             const wCount = countWaterCol(gridData, c);
             const bCount = countBoatCol(gridData, c);
             
             const wBools = gridData.cells.flatMap(r => [r[c].c_left === Content.Water, r[c].c_right === Content.Water]);
             const bBools = gridData.cells.flatMap(r => [r[c].c_left === Content.Boat, r[c].c_right === Content.Boat]);
             
             return (
              <div class="w-8 sm:w-10 md:w-12 flex flex-col justify-end items-center pb-2 text-sm sm:text-base font-mono gap-1">
                 {(hint.water_count >= 0 || hint.water_count_type !== HintType.Hidden) && <span class={getHintColor(wCount, hint.water_count, true, hint.water_count_type, wBools)}>{renderHint(hint.water_count, hint.water_count_type, true)}</span>}
                 {(hint.boat_count >= 0 || hint.boat_count_type !== HintType.Hidden) && <span class={getHintColor(bCount, hint.boat_count, false, hint.boat_count_type, bBools)}>{renderHint(hint.boat_count, hint.boat_count_type, false)}</span>}
              </div>
            );
          })}
        </div>
      </div>

      {/* Grid Body */}
      {gridData.cells.map((rowCells, r) => {
        const wCountRow = countWaterRow(gridData, r);
        const bCountRow = countBoatRow(gridData, r);
        const wBools = rowCells.flatMap(c => [c.c_left === Content.Water, c.c_right === Content.Water]);
        const bBools = rowCells.flatMap(c => [c.c_left === Content.Boat, c.c_right === Content.Boat]);
        return (
        <div class="flex">
          {/* Row hint */}
          <div class="w-16 sm:w-20 md:w-24 flex items-center justify-end pr-4 gap-2 text-sm sm:text-base font-mono">
             {(gridData.row_hints[r].water_count >= 0 || gridData.row_hints[r].water_count_type !== HintType.Hidden) && <span class={getHintColor(wCountRow, gridData.row_hints[r].water_count, true, gridData.row_hints[r].water_count_type, wBools)}>{renderHint(gridData.row_hints[r].water_count, gridData.row_hints[r].water_count_type, true)}</span>}
             {(gridData.row_hints[r].boat_count >= 0 || gridData.row_hints[r].boat_count_type !== HintType.Hidden) && <span class={getHintColor(bCountRow, gridData.row_hints[r].boat_count, false, gridData.row_hints[r].boat_count_type, bBools)}>{renderHint(gridData.row_hints[r].boat_count, gridData.row_hints[r].boat_count_type, false)}</span>}
          </div>
          {/* Row cells */}
          <div class="flex">
            {rowCells.map((cell, c) => {
              const hasBottomWall = gridData.wall_bottom?.[r]?.[c] ?? false;
              const hasRightWall = gridData.wall_right?.[r]?.[c] ?? false;
              const hasTopWall = r > 0 ? (gridData.wall_bottom?.[r - 1]?.[c] ?? false) : false;
              const hasLeftWall = c > 0 ? (gridData.wall_right?.[r]?.[c - 1] ?? false) : false;
              
              const isBlockTop = isBlockSide(r - 1, c, 'bottom');
              const isBlockBottom = isBlockSide(r + 1, c, 'top');
              const isBlockLeft = isBlockSide(r, c - 1, 'right');
              const isBlockRight = isBlockSide(r, c + 1, 'left');
              
              return (
                <Cell 
                  cell={cell} 
                  row={r} 
                  col={c} 
                  hasBottomWall={hasBottomWall} 
                  hasRightWall={hasRightWall}
                  hasTopWall={hasTopWall}
                  hasLeftWall={hasLeftWall}
                  isBlockTopNeighbor={isBlockTop}
                  isBlockBottomNeighbor={isBlockBottom}
                  isBlockLeftNeighbor={isBlockLeft}
                  isBlockRightNeighbor={isBlockRight}
                  isTopEdge={r === 0}
                  isLeftEdge={c === 0}
                  isBottomEdge={r === rows - 1}
                  isRightEdge={c === cols - 1}
                  onPointerDown={onCellPointerDown}
                  onPointerEnter={onCellPointerEnter}
                  onPointerUp={onCellPointerUp}
                />
              );
            })}
          </div>
        </div>
      )})}
    </div>
  );
}
