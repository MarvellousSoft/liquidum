import { h } from 'preact';
import { Corner, Content, CellType, HintType, countWaterRow, countWaterCol, countBoatRow, countBoatCol, isTogether, rowBools, colBools } from '../model/GridData';
import type { GridModelData } from '../model/GridData';
import type { GameSettings } from '../engine/SettingsManager';
import { Cell } from './Cell';

interface GridProps {
  gridData: GridModelData;
  settings?: GameSettings;
  hoveredCell?: { row: number; col: number; corner: Corner } | null;
  selectedTool?: Content;
  previewMap?: Map<string, Content> | null;
  blinkingCells?: Map<string, { corner: Corner, timestamp: number }>;
  onCellPointerDown?: (row: number, col: number, corner: Corner, e: PointerEvent) => void;
  onCellPointerEnter?: (row: number, col: number, corner: Corner, e: PointerEvent) => void;
  onCellPointerMove?: (row: number, col: number, corner: Corner, e: PointerEvent) => void;
  onCellPointerLeave?: (row: number, col: number, e: PointerEvent) => void;
  onCellPointerUp?: (row: number, col: number, e: PointerEvent) => void;
}

export function Grid({
  gridData,
  settings,
  hoveredCell,
  selectedTool,
  previewMap,
  blinkingCells,
  onCellPointerDown,
  onCellPointerEnter,
  onCellPointerMove,
  onCellPointerLeave,
  onCellPointerUp
}: GridProps) {
  const rows = gridData.cells.length;
  const cols = rows > 0 ? gridData.cells[0].length : 0;

  if (rows === 0 || cols === 0) return <div>Empty Grid</div>;

  const showOppositeHints = settings?.line_info === 'missing' || settings?.line_info === 'current';

  const getHintClass = (current: number, target: number, isWater: boolean, targetType: HintType, bools: boolean[]) => {
    let colorClass = 'hint-normal';

    const allowHighlight = settings?.highlight_finished_row_col ?? true;
    const progressOnUnknown = settings?.progress_on_unknown ?? true;

    if (target < 0) {
      if (targetType !== HintType.Hidden && targetType !== HintType.Zero) {
        if (isTogether(bools) === targetType) {
          if (allowHighlight) {
            colorClass = isWater ? 'hint-satisfied-water' : 'hint-satisfied-boat';
          }
        }
      } else if (progressOnUnknown && current > 0) {
        if (allowHighlight) {
          colorClass = isWater ? 'hint-satisfied-water' : 'hint-satisfied-boat';
        }
      }
    } else {
      const countOk = current === target;
      const typeOk = targetType === HintType.Hidden || isTogether(bools) === targetType;
      if (countOk && typeOk) {
        if (allowHighlight) {
          colorClass = isWater ? 'hint-satisfied-water' : 'hint-satisfied-boat';
        }
      } else if (current > target) {
        colorClass = 'hint-over';
      }
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
    if (settings?.hide_unknown && count === -1 && (type === HintType.Hidden || type === HintType.Zero) && isWater) {
      return '';
    }

    const boatImg = isWater ? null : <img src="/icons/boat_small.png" class="hint-boat-icon" alt="boat" />;
    const boatChar = isWater ? '' : '⛵';
    if (count >= 0) {
      if (type === HintType.Together) {
        return (
          <span class="inline-flex items-center whitespace-nowrap flex-nowrap">
            {boatImg}{`{ ${count} }`}
            <span class="sr-only">{boatChar}{count}</span>
          </span>
        );
      }
      if (type === HintType.Separated) {
        return (
          <span class="inline-flex items-center whitespace-nowrap flex-nowrap">
            {boatImg}{`- ${count} -`}
            <span class="sr-only">{boatChar}{count}</span>
          </span>
        );
      }
      return (
        <span class="inline-flex items-center whitespace-nowrap flex-nowrap">
          {boatImg}{count}
          <span class="sr-only">{boatChar}{count}</span>
        </span>
      );
    }
    if (type === HintType.Together) {
      return (
        <span class="inline-flex items-center whitespace-nowrap flex-nowrap">
          {boatImg}{`{ ? }`}
          <span class="sr-only">{boatChar}{'{?}'}</span>
        </span>
      );
    }
    if (type === HintType.Separated) {
      return (
        <span class="inline-flex items-center whitespace-nowrap flex-nowrap">
          {boatImg}{`- ? -`}
          <span class="sr-only">{boatChar}{'-?-'}</span>
        </span>
      );
    }
    if (type === HintType.Zero) {
      return (
        <span class="inline-flex items-center whitespace-nowrap flex-nowrap">
          {boatImg}0
          <span class="sr-only">{boatChar}0</span>
        </span>
      );
    }
    return (
      <span class="inline-flex items-center whitespace-nowrap flex-nowrap">
        {boatImg}?
        <span class="sr-only">{boatChar}?</span>
      </span>
    );
  };

  const isWaterAbove = (r: number, c: number): boolean => {
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

  const hasDualRowHints = gridData.row_hints.some(
    h => (h.water_count >= 0 || h.water_count_type !== HintType.Hidden) &&
         (h.boat_count >= 0 || h.boat_count_type !== HintType.Hidden)
  );

  const renderOppositeRowHint = (r: number) => {
    const hint = gridData.row_hints[r];
    const wCount = countWaterRow(gridData, r);
    const bCount = countBoatRow(gridData, r);

    if (settings?.line_info === 'missing') {
      const showWater = hint.water_count >= 0;
      const missingWater = showWater ? Math.max(0, hint.water_count - wCount) : null;
      const showBoat = hint.boat_count > 0;
      const missingBoat = showBoat ? Math.max(0, hint.boat_count - bCount) : null;

      if (missingWater === null && missingBoat === null) return null;

      return (
        <span class="inline-flex items-center gap-1 opacity-60 godot-text-outline font-bold text-sm">
          {missingBoat !== null && (
            <span class="inline-flex items-center">
              <img src="/icons/boat_small.png" class="hint-boat-icon" alt="boat" />
              {missingBoat}
            </span>
          )}
          {missingWater !== null && <span>{missingWater}</span>}
        </span>
      );
    }

    if (settings?.line_info === 'current') {
      const showWater = true;
      const showBoat = (hint.boat_count >= 0 || hint.boat_count_type !== HintType.Hidden) && bCount > 0;

      return (
        <span class="inline-flex items-center gap-1 opacity-60 godot-text-outline font-bold text-sm">
          {showBoat && (
            <span class="inline-flex items-center">
              <img src="/icons/boat_small.png" class="hint-boat-icon" alt="boat" />
              {bCount}
            </span>
          )}
          {showWater && <span>{wCount}</span>}
        </span>
      );
    }

    return null;
  };

  const renderOppositeColHint = (c: number) => {
    const hint = gridData.col_hints[c];
    const wCount = countWaterCol(gridData, c);
    const bCount = countBoatCol(gridData, c);

    if (settings?.line_info === 'missing') {
      const showWater = hint.water_count >= 0;
      const missingWater = showWater ? Math.max(0, hint.water_count - wCount) : null;
      const showBoat = hint.boat_count > 0;
      const missingBoat = showBoat ? Math.max(0, hint.boat_count - bCount) : null;

      if (missingWater === null && missingBoat === null) return null;

      return (
        <span class="inline-flex items-center gap-1 opacity-60 godot-text-outline font-bold text-sm">
          {missingBoat !== null && (
            <span class="inline-flex items-center">
              <img src="/icons/boat_small.png" class="hint-boat-icon" alt="boat" />
              {missingBoat}
            </span>
          )}
          {missingWater !== null && <span>{missingWater}</span>}
        </span>
      );
    }

    if (settings?.line_info === 'current') {
      const showWater = true;
      const showBoat = (hint.boat_count >= 0 || hint.boat_count_type !== HintType.Hidden) && bCount > 0;

      return (
        <span class="inline-flex items-center gap-1 opacity-60 godot-text-outline font-bold text-sm">
          {showBoat && (
            <span class="inline-flex items-center">
              <img src="/icons/boat_small.png" class="hint-boat-icon" alt="boat" />
              {bCount}
            </span>
          )}
          {showWater && <span>{wCount}</span>}
        </span>
      );
    }

    return null;
  };

  const rootClasses = [
    'inline-block',
    'relative',
    hasDualRowHints ? 'has-dual-row-hints' : '',
    settings?.bigger_hints_font ? 'bigger-hints' : '',
    settings?.thicker_walls ? 'thicker-walls' : '',
  ].filter(Boolean).join(' ');

  return (
    <div class={rootClasses}>
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
                 {(hint.boat_count >= 0 || hint.boat_count_type !== HintType.Hidden) && (
                   <span class={getHintClass(bCount, hint.boat_count, false, hint.boat_count_type, bBools)}>
                      {renderHint(hint.boat_count, hint.boat_count_type, false)}
                   </span>
                 )}
                 {(!settings?.hide_unknown || hint.water_count >= 0 || (hint.water_count_type !== HintType.Hidden && hint.water_count_type !== HintType.Zero)) && (
                   <span class={getHintClass(wCount, hint.water_count, true, hint.water_count_type, wBools)}>
                      {renderHint(hint.water_count, hint.water_count_type, true)}
                   </span>
                 )}
              </div>
            );
          })}
        </div>
        {/* Empty top-right corner if opposite row hints are shown */}
        {showOppositeHints && <div class="grid-corner-spacer-opposite" />}
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
             {(gridData.row_hints[r].boat_count >= 0 || gridData.row_hints[r].boat_count_type !== HintType.Hidden) && (
               <span class={getHintClass(bCountRow, gridData.row_hints[r].boat_count, false, gridData.row_hints[r].boat_count_type, bBools)}>
                 {renderHint(gridData.row_hints[r].boat_count, gridData.row_hints[r].boat_count_type, false)}
               </span>
             )}
             {(!settings?.hide_unknown || gridData.row_hints[r].water_count >= 0 || (gridData.row_hints[r].water_count_type !== HintType.Hidden && gridData.row_hints[r].water_count_type !== HintType.Zero)) && (
               <span class={getHintClass(wCountRow, gridData.row_hints[r].water_count, true, gridData.row_hints[r].water_count_type, wBools)}>
                 {renderHint(gridData.row_hints[r].water_count, gridData.row_hints[r].water_count_type, true)}
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
              const errorInfo = blinkingCells?.get(`${r}-${c}`);
              const hasError = Boolean(errorInfo);
              const errorCorner = errorInfo?.corner ?? null;

              const isHoveredRow = settings?.highlight_grid ? hoveredCell?.row === r : false;
              const isHoveredCol = settings?.highlight_grid ? hoveredCell?.col === c : false;
              const isHoveredCell = hoveredCell?.row === r && hoveredCell?.col === c;
              const previewTool = (settings?.show_grid_preview && isHoveredCell) ? (selectedTool ?? null) : null;
              
              let previewCorners: Partial<Record<Corner, Content>> | null = null;
              if (settings?.show_grid_preview && previewMap) {
                if (cell.type === CellType.Single) {
                  const t = previewMap.get(`${r}-${c}-${Corner.TopLeft}`);
                  if (t !== undefined) {
                    previewCorners = { [Corner.TopLeft]: t };
                  }
                } else if (cell.type === CellType.IncDiag) {
                  const tl = previewMap.get(`${r}-${c}-${Corner.TopLeft}`);
                  const br = previewMap.get(`${r}-${c}-${Corner.BottomRight}`);
                  if (tl !== undefined || br !== undefined) {
                    previewCorners = {};
                    if (tl !== undefined) previewCorners[Corner.TopLeft] = tl;
                    if (br !== undefined) previewCorners[Corner.BottomRight] = br;
                  }
                } else if (cell.type === CellType.DecDiag) {
                  const tr = previewMap.get(`${r}-${c}-${Corner.TopRight}`);
                  const bl = previewMap.get(`${r}-${c}-${Corner.BottomLeft}`);
                  if (tr !== undefined || bl !== undefined) {
                    previewCorners = {};
                    if (tr !== undefined) previewCorners[Corner.TopRight] = tr;
                    if (bl !== undefined) previewCorners[Corner.BottomLeft] = bl;
                  }
                }
              }

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
                  hasError={hasError}
                  errorCorner={errorCorner}
                  isHoveredRow={isHoveredRow}
                  isHoveredCol={isHoveredCol}
                  isHoveredCell={isHoveredCell}
                  hoveredCorner={isHoveredCell ? (hoveredCell?.corner ?? null) : null}
                  previewTool={previewTool}
                  previewCorners={previewCorners}
                  onPointerDown={onCellPointerDown}
                  onPointerEnter={onCellPointerEnter}
                  onPointerMove={onCellPointerMove}
                  onPointerLeave={onCellPointerLeave}
                  onPointerUp={onCellPointerUp}
                />
              );
            })}
          </div>
          {/* Opposite row hint on the right */}
          {showOppositeHints && (
            <div
              data-testid={`row-hint-opposite-${r}`}
              class="row-hint row-hint-opposite flex items-center justify-center"
            >
              {renderOppositeRowHint(r)}
            </div>
          )}
        </div>
      );
    })}

      {/* Bottom hints bar (opposite column hints) */}
      {showOppositeHints && (
        <div class="flex bottom-hints-bar">
          <div class="grid-corner-spacer" />
          <div class="flex" style={{ width: `calc(${cols} * var(--cell-size, 3rem))` }}>
            {gridData.col_hints.map((hint, c) => (
              <div
                key={c}
                data-testid={`col-hint-opposite-${c}`}
                class="col-hint col-hint-opposite flex items-center justify-center"
              >
                {renderOppositeColHint(c)}
              </div>
            ))}
          </div>
          <div class="grid-corner-spacer-opposite" />
        </div>
      )}

      {/* Bottom right grid size indicator like in original Godot game */}
      <div class="flex justify-end items-center mt-2 pr-1 select-none pointer-events-none">
        <span
          data-testid="grid-size-label"
          class="grid-size-label godot-text-outline"
        >
          {rows}x{cols}
        </span>
      </div>
    </div>
  );
}
