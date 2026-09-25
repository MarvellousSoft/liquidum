import { h } from 'preact';
import { useState, useEffect } from 'preact/hooks';
import { Corner, Content, CellType, HintType, countWaterRow, countWaterCol, countBoatRow, countBoatCol, isTogether, rowBools, colBools, getHintHoverText } from '../model/GridData';
import type { GridModelData } from '../model/GridData';
import type { GameSettings } from '../engine/SettingsManager';
import { t } from '../i18n';
import { Cell } from './Cell';

interface GridProps {
  gridData: GridModelData;
  settings?: GameSettings;
  hoveredCell?: { row: number; col: number; corner: Corner } | null;
  selectedTool?: Content;
  previewMap?: Map<string, Content> | null;
  blinkingCells?: Map<string, { corner: Corner, timestamp: number }>;
  resetTrigger?: number;
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
  resetTrigger,
  onCellPointerDown,
  onCellPointerEnter,
  onCellPointerMove,
  onCellPointerLeave,
  onCellPointerUp
}: GridProps) {
  const rows = gridData.cells.length;
  const cols = rows > 0 ? gridData.cells[0].length : 0;

  const [hoveredHint, setHoveredHint] = useState<{ type: 'row' | 'col'; index: number } | null>(null);
  const activeHoveredHint = hoveredCell ? null : hoveredHint;

  const [dimmedHints, setDimmedHints] = useState<Set<string>>(new Set());

  // Reset dimmed hints when level loads or restarts
  useEffect(() => {
    setDimmedHints(new Set());
  }, [resetTrigger, rows, cols]);

  if (rows === 0 || cols === 0) return <div>Empty Grid</div>;

  const showOppositeHints = settings?.line_info === 'missing' || settings?.line_info === 'current';

  const isRowBoatDimmed = (r: number) => dimmedHints.has(`row-${r}`) || dimmedHints.has(`row-${r}-boat`);
  const isRowWaterDimmed = (r: number) => dimmedHints.has(`row-${r}`) || dimmedHints.has(`row-${r}-water`);
  const isRowDimmed = (r: number) => dimmedHints.has(`row-${r}`) || (isRowBoatDimmed(r) && isRowWaterDimmed(r));

  const isColBoatDimmed = (c: number) => dimmedHints.has(`col-${c}`) || dimmedHints.has(`col-${c}-boat`);
  const isColWaterDimmed = (c: number) => dimmedHints.has(`col-${c}`) || dimmedHints.has(`col-${c}-water`);
  const isColDimmed = (c: number) => dimmedHints.has(`col-${c}`) || (isColBoatDimmed(c) && isColWaterDimmed(c));

  const toggleDim = (type: 'row' | 'col', index: number, part: 'all' | 'boat' | 'water' = 'all') => {
    setDimmedHints(prev => {
      const next = new Set(prev);
      const mainKey = `${type}-${index}`;
      const boatKey = `${type}-${index}-boat`;
      const waterKey = `${type}-${index}-water`;

      if (part === 'all') {
        const currentlyDimmed = next.has(mainKey) || (next.has(boatKey) && next.has(waterKey));
        if (currentlyDimmed) {
          next.delete(mainKey);
          next.delete(boatKey);
          next.delete(waterKey);
        } else {
          next.add(mainKey);
          next.delete(boatKey);
          next.delete(waterKey);
        }
      } else if (part === 'boat') {
        if (next.has(mainKey)) {
          next.delete(mainKey);
          next.add(waterKey);
        } else if (next.has(boatKey)) {
          next.delete(boatKey);
        } else {
          next.add(boatKey);
        }
      } else if (part === 'water') {
        if (next.has(mainKey)) {
          next.delete(mainKey);
          next.add(boatKey);
        } else if (next.has(waterKey)) {
          next.delete(waterKey);
        } else {
          next.add(waterKey);
        }
      }
      return next;
    });
  };


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
    h => h.boat_count >= 0 || h.boat_count_type !== HintType.Hidden
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

  const getOppositeRowHoverText = (r: number): string | undefined => {
    if (!showOppositeHints) return undefined;
    const hint = gridData.row_hints[r];
    const wCount = countWaterRow(gridData, r);
    const bCount = countBoatRow(gridData, r);
    const line = t('hints.line_row');

    if (settings?.line_info === 'missing') {
      const showWater = hint.water_count >= 0;
      const missingWater = showWater ? Math.max(0, hint.water_count - wCount) : null;
      const showBoat = hint.boat_count > 0;
      const missingBoat = showBoat ? Math.max(0, hint.boat_count - bCount) : null;

      if (missingWater === null && missingBoat === null) return undefined;

      const parts: string[] = [];
      if (missingWater !== null) {
        parts.push(
          missingWater === 0
            ? t('hints.opp_no_missing_water')
            : missingWater === 1
            ? t('hints.opp_missing_water_one')
            : t('hints.opp_missing_water_many', { count: missingWater })
        );
      }
      if (missingBoat !== null) {
        parts.push(
          missingBoat === 0
            ? t('hints.opp_no_missing_boats')
            : missingBoat === 1
            ? t('hints.opp_missing_boats_one')
            : t('hints.opp_missing_boats_many', { count: missingBoat })
        );
      }
      return t('hints.opp_remaining', { line, parts: parts.join(', ') });
    }

    if (settings?.line_info === 'current') {
      const parts: string[] = [];
      parts.push(wCount === 1 ? t('hints.opp_water_one') : t('hints.opp_water_many', { count: wCount }));
      if ((hint.boat_count >= 0 || hint.boat_count_type !== HintType.Hidden) && bCount > 0) {
        parts.push(bCount === 1 ? t('hints.opp_boat_one') : t('hints.opp_boat_many', { count: bCount }));
      }
      return t('hints.opp_placed', { line, parts: parts.join(', ') });
    }

    return undefined;
  };

  const getOppositeColHoverText = (c: number): string | undefined => {
    if (!showOppositeHints) return undefined;
    const hint = gridData.col_hints[c];
    const wCount = countWaterCol(gridData, c);
    const bCount = countBoatCol(gridData, c);
    const line = t('hints.line_col');

    if (settings?.line_info === 'missing') {
      const showWater = hint.water_count >= 0;
      const missingWater = showWater ? Math.max(0, hint.water_count - wCount) : null;
      const showBoat = hint.boat_count > 0;
      const missingBoat = showBoat ? Math.max(0, hint.boat_count - bCount) : null;

      if (missingWater === null && missingBoat === null) return undefined;

      const parts: string[] = [];
      if (missingWater !== null) {
        parts.push(
          missingWater === 0
            ? t('hints.opp_no_missing_water')
            : missingWater === 1
            ? t('hints.opp_missing_water_one')
            : t('hints.opp_missing_water_many', { count: missingWater })
        );
      }
      if (missingBoat !== null) {
        parts.push(
          missingBoat === 0
            ? t('hints.opp_no_missing_boats')
            : missingBoat === 1
            ? t('hints.opp_missing_boats_one')
            : t('hints.opp_missing_boats_many', { count: missingBoat })
        );
      }
      return t('hints.opp_remaining', { line, parts: parts.join(', ') });
    }

    if (settings?.line_info === 'current') {
      const parts: string[] = [];
      parts.push(wCount === 1 ? t('hints.opp_water_one') : t('hints.opp_water_many', { count: wCount }));
      if ((hint.boat_count >= 0 || hint.boat_count_type !== HintType.Hidden) && bCount > 0) {
        parts.push(bCount === 1 ? t('hints.opp_boat_one') : t('hints.opp_boat_many', { count: bCount }));
      }
      return t('hints.opp_placed', { line, parts: parts.join(', ') });
    }

    return undefined;
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

            const showBoatHint = hint.boat_count >= 0 || hint.boat_count_type !== HintType.Hidden;
            const showWaterHint = !settings?.hide_unknown || hint.water_count >= 0 || (hint.water_count_type !== HintType.Hidden && hint.water_count_type !== HintType.Zero);

            const boatTitle = showBoatHint ? getHintHoverText(hint.boat_count, hint.boat_count_type, false, false) : undefined;
            const waterTitle = showWaterHint ? getHintHoverText(hint.water_count, hint.water_count_type, true, false) : undefined;
            const cellTitle = [boatTitle, waterTitle].filter(Boolean).join('\n') || undefined;

            const isColHighlighted = (settings?.highlight_grid ?? true)
              ? (hoveredCell?.col === c || (activeHoveredHint?.type === 'col' && activeHoveredHint.index === c))
              : false;

            const isDualCol = showBoatHint && showWaterHint;

            return (
              <div
                key={c}
                data-testid={`col-hint-${c}`}
                data-col={c}
                data-dimmed={isColDimmed(c) ? 'true' : 'false'}
                class={`col-hint ${showBoatHint ? 'has-boat-hint' : ''} ${isColHighlighted ? 'hint-hovered' : ''} ${isColDimmed(c) ? 'hint-dimmed' : ''}`}
                title={cellTitle}
                onPointerEnter={() => setHoveredHint({ type: 'col', index: c })}
                onPointerLeave={() => setHoveredHint(null)}
                onPointerDown={(e) => {
                  if (e.button === 2) {
                    e.preventDefault();
                    e.stopPropagation();
                  }
                }}
                onContextMenu={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  toggleDim('col', c, 'all');
                }}
              >
                {showBoatHint && (
                  <span
                    class={`${getHintClass(bCount, hint.boat_count, false, hint.boat_count_type, bBools)} ${isColBoatDimmed(c) ? 'hint-dimmed' : ''}`}
                    title={boatTitle}
                    data-dimmed={isColBoatDimmed(c) ? 'true' : 'false'}
                    onPointerDown={(e) => {
                      if (e.button === 2) {
                        e.preventDefault();
                        e.stopPropagation();
                      }
                    }}
                    onContextMenu={(e) => {
                      if (isDualCol) {
                        e.preventDefault();
                        e.stopPropagation();
                        toggleDim('col', c, 'boat');
                      }
                    }}
                  >
                    {renderHint(hint.boat_count, hint.boat_count_type, false)}
                  </span>
                )}
                {showWaterHint && (
                  <span
                    class={`${getHintClass(wCount, hint.water_count, true, hint.water_count_type, wBools)} ${isColWaterDimmed(c) ? 'hint-dimmed' : ''}`}
                    title={waterTitle}
                    data-dimmed={isColWaterDimmed(c) ? 'true' : 'false'}
                    onPointerDown={(e) => {
                      if (e.button === 2) {
                        e.preventDefault();
                        e.stopPropagation();
                      }
                    }}
                    onContextMenu={(e) => {
                      if (isDualCol) {
                        e.preventDefault();
                        e.stopPropagation();
                        toggleDim('col', c, 'water');
                      }
                    }}
                  >
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

        const hint = gridData.row_hints[r];
        const showBoatHint = hint.boat_count >= 0 || hint.boat_count_type !== HintType.Hidden;
        const showWaterHint = !settings?.hide_unknown || hint.water_count >= 0 || (hint.water_count_type !== HintType.Hidden && hint.water_count_type !== HintType.Zero);

        const boatTitle = showBoatHint ? getHintHoverText(hint.boat_count, hint.boat_count_type, false, true) : undefined;
        const waterTitle = showWaterHint ? getHintHoverText(hint.water_count, hint.water_count_type, true, true) : undefined;
        const cellTitle = [boatTitle, waterTitle].filter(Boolean).join('\n') || undefined;

        const isRowHighlighted = (settings?.highlight_grid ?? true)
          ? (hoveredCell?.row === r || (activeHoveredHint?.type === 'row' && activeHoveredHint.index === r))
          : false;

        return (
          <div key={r} class="flex">
            {/* Row hint */}
            <div
              data-testid={`row-hint-${r}`}
              data-row={r}
              data-dimmed={isRowDimmed(r) ? 'true' : 'false'}
              class={`row-hint ${isRowHighlighted ? 'hint-hovered' : ''} ${isRowDimmed(r) ? 'hint-dimmed' : ''}`}
              title={cellTitle}
              onPointerEnter={() => setHoveredHint({ type: 'row', index: r })}
              onPointerLeave={() => setHoveredHint(null)}
              onPointerDown={(e) => {
                if (e.button === 2) {
                  e.preventDefault();
                  e.stopPropagation();
                }
              }}
              onContextMenu={(e) => {
                e.preventDefault();
                e.stopPropagation();
                toggleDim('row', r, 'all');
              }}
            >
              {hasDualRowHints ? (
                <>
                  <span
                    class={`row-hint-boat-slot ${isRowBoatDimmed(r) ? 'hint-dimmed' : ''}`}
                    data-dimmed={isRowBoatDimmed(r) ? 'true' : 'false'}
                    onPointerDown={(e) => {
                      if (e.button === 2) {
                        e.preventDefault();
                        e.stopPropagation();
                      }
                    }}
                    onContextMenu={(e) => {
                      e.preventDefault();
                      e.stopPropagation();
                      toggleDim('row', r, 'boat');
                    }}
                  >
                    {showBoatHint && (
                      <span
                        class={`row-hint-boat ${getHintClass(bCountRow, hint.boat_count, false, hint.boat_count_type, bBools)}`}
                        title={boatTitle}
                      >
                        {renderHint(hint.boat_count, hint.boat_count_type, false)}
                      </span>
                    )}
                  </span>
                  <span
                    class={`row-hint-water-slot ${isRowWaterDimmed(r) ? 'hint-dimmed' : ''}`}
                    data-dimmed={isRowWaterDimmed(r) ? 'true' : 'false'}
                    onPointerDown={(e) => {
                      if (e.button === 2) {
                        e.preventDefault();
                        e.stopPropagation();
                      }
                    }}
                    onContextMenu={(e) => {
                      e.preventDefault();
                      e.stopPropagation();
                      toggleDim('row', r, 'water');
                    }}
                  >
                    {showWaterHint && (
                      <span
                        class={`row-hint-water ${getHintClass(wCountRow, hint.water_count, true, hint.water_count_type, wBools)}`}
                        title={waterTitle}
                      >
                        {renderHint(hint.water_count, hint.water_count_type, true)}
                      </span>
                    )}
                  </span>
                </>
              ) : (
                showWaterHint && (
                  <span
                    class={getHintClass(wCountRow, hint.water_count, true, hint.water_count_type, wBools)}
                    title={waterTitle}
                  >
                    {renderHint(hint.water_count, hint.water_count_type, true)}
                  </span>
                )
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

                const isHoveredRowCell = (settings?.highlight_grid ?? true)
                  ? (hoveredCell?.row === r || (activeHoveredHint?.type === 'row' && activeHoveredHint.index === r))
                  : false;
                const isHoveredColCell = (settings?.highlight_grid ?? true)
                  ? (hoveredCell?.col === c || (activeHoveredHint?.type === 'col' && activeHoveredHint.index === c))
                  : false;
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
                    isHoveredRow={isHoveredRowCell}
                    isHoveredCol={isHoveredColCell}
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
                data-dimmed={isRowDimmed(r) ? 'true' : 'false'}
                class={`row-hint row-hint-opposite flex items-center justify-center ${isRowHighlighted ? 'hint-hovered' : ''} ${isRowDimmed(r) ? 'hint-dimmed' : ''}`}
                title={getOppositeRowHoverText(r)}
                onPointerEnter={() => setHoveredHint({ type: 'row', index: r })}
                onPointerLeave={() => setHoveredHint(null)}
                onPointerDown={(e) => {
                  if (e.button === 2) {
                    e.preventDefault();
                    e.stopPropagation();
                  }
                }}
                onContextMenu={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  toggleDim('row', r, 'all');
                }}
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
            {gridData.col_hints.map((hint, c) => {
              const isColHighlighted = (settings?.highlight_grid ?? true)
                ? (hoveredCell?.col === c || (activeHoveredHint?.type === 'col' && activeHoveredHint.index === c))
                : false;
              return (
                <div
                  key={c}
                  data-testid={`col-hint-opposite-${c}`}
                  data-dimmed={isColDimmed(c) ? 'true' : 'false'}
                  class={`col-hint col-hint-opposite flex items-center justify-center ${isColHighlighted ? 'hint-hovered' : ''} ${isColDimmed(c) ? 'hint-dimmed' : ''}`}
                  title={getOppositeColHoverText(c)}
                  onPointerEnter={() => setHoveredHint({ type: 'col', index: c })}
                  onPointerLeave={() => setHoveredHint(null)}
                  onPointerDown={(e) => {
                    if (e.button === 2) {
                      e.preventDefault();
                      e.stopPropagation();
                    }
                  }}
                  onContextMenu={(e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    toggleDim('col', c, 'all');
                  }}
                >
                  {renderOppositeColHint(c)}
                </div>
              );
            })}
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
