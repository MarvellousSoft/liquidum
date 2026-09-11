import { h } from 'preact';
import { Corner, Content, CellType, HintType, countWaterRow, countWaterCol, countBoatRow, countBoatCol, isTogether, rowBools, colBools } from '../model/GridData';
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

  const getHintClass = (current: number, target: number, isWater: boolean, targetType: HintType, bools: boolean[]) => {
    if (target < 0 && targetType === HintType.Hidden) return 'opacity-0';
    let colorClass = 'hint-normal';
    if (target < 0) {
      if (isTogether(bools) === targetType) colorClass = isWater ? 'hint-satisfied-water' : 'hint-satisfied-boat';
    } else {
      const countOk = current === target;
      const typeOk = targetType === HintType.Hidden || isTogether(bools) === targetType;
      if (countOk && typeOk) colorClass = isWater ? 'hint-satisfied-water' : 'hint-satisfied-boat';
      else if (current > target) colorClass = 'hint-over';
    }
    return `${colorClass} godot-text-outline`;
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
    const boatImg = isWater ? null : <img src="/icons/boat_small.png" class="hint-boat-icon" alt="boat" />;
    const boatChar = isWater ? '' : '⛵';
    if (count >= 0) {
      if (type === HintType.Together) {
        return (
          <span class="flex items-center">
            {boatImg}{`{ ${count} }`}
            <span class="sr-only">{boatChar}{count}</span>
          </span>
        );
      }
      if (type === HintType.Separated) {
        return (
          <span class="flex items-center">
            {boatImg}{`- ${count} -`}
            <span class="sr-only">{boatChar}{count}</span>
          </span>
        );
      }
      return (
        <span class="flex items-center">
          {boatImg}{count}
          <span class="sr-only">{boatChar}{count}</span>
        </span>
      );
    }
    if (type === HintType.Together) {
      return (
        <span class="flex items-center">
          {boatImg}{`{ ? }`}
          <span class="sr-only">{boatChar}{'{?}'}</span>
        </span>
      );
    }
    if (type === HintType.Separated) {
      return (
        <span class="flex items-center">
          {boatImg}{`- ? -`}
          <span class="sr-only">{boatChar}{'-?-'}</span>
        </span>
      );
    }
    if (type === HintType.Zero) {
      return (
        <span class="flex items-center">
          {boatImg}0
          <span class="sr-only">{boatChar}0</span>
        </span>
      );
    }
    return '';
  };  const isWaterAbove = (r: number, c: number): boolean => {
    if (r <= 0) return false;
    const hasTopWall = gridData.wall_bottom?.[r - 1]?.[c] ?? false;
    if (hasTopWall) return false;
    const cellAbove = gridData.cells[r - 1]?.[c];
    if (!cellAbove) return false;
    if (cellAbove.type === CellType.Single) {
      return cellAbove.c_left === Content.Water;
    }
    if (cellAbove.type === CellType.IncDiag) {
      return cellAbove.c_right === Content.Water;
    }
    if (cellAbove.type === CellType.DecDiag) {
      return cellAbove.c_left === Content.Water;
    }
    return false;
  };

  return (
    <div class="inline-block relative">
      {/* Column Hints Header */}
      <div class="flex">
        {/* Empty top-left corner */}
        <div class="grid-corner-spacer" />
        {/* Column hints */}
        <div class="flex" style={{ width: `calc(${cols} * var(--cell-size, 3rem))` }}>
          {gridData.col_hints.map((hint, c) => {
             const wCount = countWaterCol(gridData, c);
             const bCount = countBoatCol(gridData, c);
             
             const wBools = colBools(gridData, c, Content.Water);
             const bBools = colBools(gridData, c, Content.Boat);
             
             return (
              <div key={c} class="col-hint">
                 {(hint.water_count >= 0 || hint.water_count_type !== HintType.Hidden) && (
                   <span class={getHintClass(wCount, hint.water_count, true, hint.water_count_type, wBools)}>
                      {renderHint(hint.water_count, hint.water_count_type, true)}
                   </span>
                 )}
                 {(hint.boat_count >= 0 || hint.boat_count_type !== HintType.Hidden) && (
                   <span class={getHintClass(bCount, hint.boat_count, false, hint.boat_count_type, bBools)}>
                      {renderHint(hint.boat_count, hint.boat_count_type, false)}
                   </span>
                 )}
              </div>
            );
          })}
        </div>
      </div>

      {/* Grid Body */}
      {gridData.cells.map((rowCells, r) => {
        const wCountRow = countWaterRow(gridData, r);
        const bCountRow = countBoatRow(gridData, r);
        
        const wBools = rowBools(gridData, r, Content.Water);
        const bBools = rowBools(gridData, r, Content.Boat);
        
        return (
        <div key={r} class="flex">
          {/* Row hint */}
          <div class="row-hint">
             {(gridData.row_hints[r].water_count >= 0 || gridData.row_hints[r].water_count_type !== HintType.Hidden) && (
               <span class={getHintClass(wCountRow, gridData.row_hints[r].water_count, true, gridData.row_hints[r].water_count_type, wBools)}>
                 {renderHint(gridData.row_hints[r].water_count, gridData.row_hints[r].water_count_type, true)}
               </span>
             )}
             {(gridData.row_hints[r].boat_count >= 0 || gridData.row_hints[r].boat_count_type !== HintType.Hidden) && (
               <span class={getHintClass(bCountRow, gridData.row_hints[r].boat_count, false, gridData.row_hints[r].boat_count_type, bBools)}>
                 {renderHint(gridData.row_hints[r].boat_count, gridData.row_hints[r].boat_count_type, false)}
               </span>
             )}
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
              const isSurface = !isWaterAbove(r, c);
              
              return (
                <Cell 
                  key={c}
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
                  isSurface={isSurface}
                  onPointerDown={onCellPointerDown}
                  onPointerEnter={onCellPointerEnter}
                  onPointerUp={onCellPointerUp}
                />
              );
            })}
          </div>
        </div>
      );
    })}
    </div>
  );
}
