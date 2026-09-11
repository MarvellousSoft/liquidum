import { h } from 'preact';
import { CellType, Content, Corner } from '../model/GridData';
import type { PureCell } from '../model/GridData';

interface CellProps {
  cell: PureCell;
  row: number;
  col: number;
  hasBottomWall: boolean;
  hasRightWall: boolean;
  hasTopWall: boolean;
  hasLeftWall: boolean;
  isBlockTopNeighbor: boolean;
  isBlockBottomNeighbor: boolean;
  isBlockLeftNeighbor: boolean;
  isBlockRightNeighbor: boolean;
  isTopEdge: boolean;
  isLeftEdge: boolean;
  isBottomEdge: boolean;
  isRightEdge: boolean;
  isSurface?: boolean;
  onPointerDown?: (row: number, col: number, corner: Corner, e: PointerEvent) => void;
  onPointerEnter?: (row: number, col: number, corner: Corner, e: PointerEvent) => void;
  onPointerUp?: (row: number, col: number, e: PointerEvent) => void;
}

const getContentName = (c: Content) => {
  switch (c) {
    case Content.Water: return 'water';
    case Content.NoWater: return 'air';
    case Content.Boat: return 'boat';
    case Content.Block: return 'block';
    case Content.NoBoat: return 'noboat';
    case Content.NoBoatWater: return 'noboatwater';
    default: return 'none';
  }
};

const getCornerAlignClass = (corner: Corner, clipped: boolean): string => {
  if (!clipped) return 'align-center';
  switch (corner) {
    case Corner.TopLeft: return 'align-top-left';
    case Corner.BottomRight: return 'align-bottom-right';
    case Corner.TopRight: return 'align-top-right';
    case Corner.BottomLeft: return 'align-bottom-left';
    default: return 'align-center';
  }
};

export function Cell({ 
  cell, row, col, 
  hasBottomWall, hasRightWall, hasTopWall, hasLeftWall, 
  isTopEdge, isLeftEdge, isBottomEdge, isRightEdge,
  isSurface = true,
  onPointerDown, onPointerEnter, onPointerUp 
}: CellProps) {
  const isWaterLeft = cell.c_left === Content.Water;
  const isWaterRight = cell.c_right === Content.Water;
  
  const isNoWaterLeft = cell.c_left === Content.NoWater || cell.c_left === Content.NoBoatWater;
  const isNoWaterRight = cell.c_right === Content.NoWater || cell.c_right === Content.NoBoatWater;

  const isBoatLeft = cell.c_left === Content.Boat;
  const isBoatRight = cell.c_right === Content.Boat;
  
  const isBlockLeft = cell.c_left === Content.Block;
  const isBlockRight = cell.c_right === Content.Block;

  const renderHalf = (corner: Corner, isWater: boolean, isNoWater: boolean, isBoat: boolean, isBlock: boolean, clipPath?: string, halfIsSurface: boolean = isSurface) => {
    const alignment = getCornerAlignClass(corner, Boolean(clipPath));
  
    let content = null;
    if (isBlock) content = <div class="cell-block" />;
    else if (isWater) content = <div class={`cell-water ${halfIsSurface ? 'is-surface' : ''}`} />;
    else if (isBoat) content = (
      <div class={`cell-boat ${alignment}`}>
        <img src="/icons/boat_small.png" alt="boat" class="cell-sprite boat-sprite" />
        <span class="sr-only">⛵</span>
      </div>
    );
    else if (isNoWater) content = (
      <div class={`cell-air ${alignment}`}>
        <img src="/icons/nowater.png" alt="air" class="cell-sprite air-sprite" />
        <span class="sr-only">✕</span>
      </div>
    );
    
    if (!content) return null;
    return clipPath ? <div class="cell-layer" style={{ clipPath }}>{content}</div> : content;
  };

  const renderDiagonalLine = (type: CellType.IncDiag | CellType.DecDiag) => {
    const isInc = type === CellType.IncDiag;
    return (
      <svg class="diag-svg">
        <line
          x1="0%"
          y1={isInc ? "100%" : "0%"}
          x2="100%"
          y2={isInc ? "0%" : "100%"}
          stroke="#000924"
          stroke-width="3"
          stroke-linecap="round"
        />
      </svg>
    );
  };

  const renderContent = () => {
    if (cell.type === CellType.Single) {
      return renderHalf(Corner.TopLeft, isWaterLeft, isNoWaterLeft, isBoatLeft, isBlockLeft, undefined, isSurface);
    } 
    
    if (cell.type === CellType.IncDiag) {
      return (
        <div class="cell-content-layer">
          {renderHalf(Corner.TopLeft, isWaterLeft, isNoWaterLeft, isBoatLeft, isBlockLeft, 'polygon(0 0, 100% 0, 0 100%)', isSurface)}
          {renderHalf(Corner.BottomRight, isWaterRight, isNoWaterRight, isBoatRight, isBlockRight, 'polygon(100% 0, 100% 100%, 0 100%)', false)}
          {renderDiagonalLine(CellType.IncDiag)}
        </div>
      );
    }
    
    if (cell.type === CellType.DecDiag) {
      return (
        <div class="cell-content-layer">
          {renderHalf(Corner.TopRight, isWaterRight, isNoWaterRight, isBoatRight, isBlockRight, 'polygon(0 0, 100% 0, 100% 100%)', isSurface)}
          {renderHalf(Corner.BottomLeft, isWaterLeft, isNoWaterLeft, isBoatLeft, isBlockLeft, 'polygon(0 0, 100% 100%, 0 100%)', false)}
          {renderDiagonalLine(CellType.DecDiag)}
        </div>
      );
    }
  };

  const getCornerFromEvent = (e: PointerEvent, el: HTMLElement): Corner => {
    if (cell.type === CellType.Single) return Corner.TopLeft;
    const rect = el.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    
    if (cell.type === CellType.IncDiag) {
      return y < (- (rect.height / rect.width) * x + rect.height) ? Corner.TopLeft : Corner.BottomRight;
    } else {
      return y < ((rect.height / rect.width) * x) ? Corner.TopRight : Corner.BottomLeft;
    }
  };

  const isBlock = cell.c_left === Content.Block && cell.type === CellType.Single;

  return (
    <div 
      data-testid={`cell-${row}-${col}`}
      data-row={row}
      data-col={col}
      data-cell-type={cell.type}
      data-content-left={getContentName(cell.c_left)}
      data-content-right={getContentName(cell.c_right)}
      class={`cell ${isBlock ? 'cell-block-bg' : ''}`}
      onPointerDown={(e) => {
        const corner = getCornerFromEvent(e, e.currentTarget as HTMLElement);
        onPointerDown?.(row, col, corner, e);
      }}
      onPointerEnter={(e) => {
        const corner = getCornerFromEvent(e, e.currentTarget as HTMLElement);
        onPointerEnter?.(row, col, corner, e);
      }}
      onPointerUp={(e) => onPointerUp?.(row, col, e)}
      onContextMenu={(e) => e.preventDefault()}
    >
      {/* Interior Grid Lines */}
      {!isRightEdge && !hasRightWall && <div class="cell-grid-line-v" />}
      {!isBottomEdge && !hasBottomWall && <div class="cell-grid-line-h" />}

      {renderContent()}
      
      {/* Overlay Thick Walls */}
      {(hasTopWall || isTopEdge) && (
        <div class={`cell-wall cell-wall-top ${isTopEdge ? 'edge-top' : ''} ${isLeftEdge ? 'edge-left' : ''} ${isRightEdge ? 'edge-right' : ''}`} />
      )}
      {(hasBottomWall || isBottomEdge) && (
        <div class={`cell-wall cell-wall-bottom ${isBottomEdge ? 'edge-bottom' : ''} ${isLeftEdge ? 'edge-left' : ''} ${isRightEdge ? 'edge-right' : ''}`} />
      )}
      {(hasLeftWall || isLeftEdge) && (
        <div class={`cell-wall cell-wall-left ${isLeftEdge ? 'edge-left' : ''} ${isTopEdge ? 'edge-top' : ''} ${isBottomEdge ? 'edge-bottom' : ''}`} />
      )}
      {(hasRightWall || isRightEdge) && (
        <div class={`cell-wall cell-wall-right ${isRightEdge ? 'edge-right' : ''} ${isTopEdge ? 'edge-top' : ''} ${isBottomEdge ? 'edge-bottom' : ''}`} />
      )}
    </div>
  );
}
