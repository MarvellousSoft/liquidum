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
  hasError?: boolean;
  errorCorner?: Corner | null;
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
  hasError = false,
  errorCorner = null,
  onPointerDown, onPointerEnter, onPointerUp 
}: CellProps) {
  const isWaterLeft = cell.c_left === Content.Water;
  const isWaterRight = cell.c_right === Content.Water;
  
  const isNoWaterLeft = cell.c_left === Content.NoWater;
  const isNoWaterRight = cell.c_right === Content.NoWater;

  const isBoatLeft = cell.c_left === Content.Boat;
  const isBoatRight = cell.c_right === Content.Boat;
  
  const isBlockLeft = cell.c_left === Content.Block;
  const isBlockRight = cell.c_right === Content.Block;

  const isNoBoatLeft = cell.c_left === Content.NoBoat;
  const isNoBoatRight = cell.c_right === Content.NoBoat;

  const isNoBoatWaterLeft = cell.c_left === Content.NoBoatWater;
  const isNoBoatWaterRight = cell.c_right === Content.NoBoatWater;

  const renderHalf = (
    corner: Corner, 
    isWater: boolean, 
    isNoWater: boolean, 
    isBoat: boolean, 
    isBlock: boolean, 
    isNoBoat: boolean,
    isNoBoatWater: boolean,
    clipPath?: string, 
    halfIsSurface: boolean = isSurface
  ) => {
    const isDiagonal = Boolean(clipPath);
    const alignment = getCornerAlignClass(corner, isDiagonal);
  
    let content = null;
    if (isBlock) content = <div class="cell-block" />;
    else if (isWater) content = <div class={`cell-water ${halfIsSurface ? 'is-surface' : ''}`} />;
    else if (isBoat) content = (
      <div class={`cell-boat ${alignment}`}>
        <img src="/icons/boat_small.png" alt="boat" class={`cell-sprite boat-sprite ${isDiagonal ? 'cell-sprite-diagonal' : ''}`} />
        <span class="sr-only">⛵</span>
      </div>
    );
    else if (isNoBoat) content = (
      <div class={`cell-maybeboat ${alignment}`}>
        <div class={`maybeboat-wrap ${isDiagonal ? 'maybeboat-wrap-diagonal' : ''}`}>
          <img src="/icons/boat_small.png" alt="maybe boat" class="maybeboat-boat" />
          <img src="/icons/question_mark.png" alt="?" class="maybeboat-question" />
        </div>
        <span class="sr-only">?</span>
      </div>
    );
    else if (isNoBoatWater) content = (
      <div class={`cell-maybeboat ${alignment}`}>
        <div class="flex items-center justify-center gap-0.5">
          <img src="/icons/nowater.png" alt="air" class={`cell-sprite air-sprite ${isDiagonal ? 'air-sprite-diagonal' : ''}`} style={{ maxWidth: '40%', maxHeight: '40%' }} />
          <div class={`maybeboat-wrap ${isDiagonal ? 'maybeboat-wrap-diagonal' : ''}`} style={{ maxWidth: '40%', maxHeight: '40%' }}>
            <img src="/icons/boat_small.png" alt="maybe boat" class="maybeboat-boat" />
            <img src="/icons/question_mark.png" alt="?" class="maybeboat-question" />
          </div>
        </div>
        <span class="sr-only">✕?</span>
      </div>
    );
    else if (isNoWater) content = (
      <div class={`cell-air ${alignment}`}>
        <img src="/icons/nowater.png" alt="air" class={`cell-sprite air-sprite ${isDiagonal ? 'air-sprite-diagonal' : ''}`} />
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
          stroke="var(--cell-wall)"
          stroke-width="3"
          stroke-linecap="round"
        />
      </svg>
    );
  };

  const renderContent = () => {
    if (cell.type === CellType.Single) {
      return renderHalf(Corner.TopLeft, isWaterLeft, isNoWaterLeft, isBoatLeft, isBlockLeft, isNoBoatLeft, isNoBoatWaterLeft, undefined, isSurface);
    } 
    
    if (cell.type === CellType.IncDiag) {
      return (
        <div class="cell-content-layer">
          {renderHalf(Corner.TopLeft, isWaterLeft, isNoWaterLeft, isBoatLeft, isBlockLeft, isNoBoatLeft, isNoBoatWaterLeft, 'polygon(0 0, 100% 0, 0 100%)', isSurface)}
          {renderHalf(Corner.BottomRight, isWaterRight, isNoWaterRight, isBoatRight, isBlockRight, isNoBoatRight, isNoBoatWaterRight, 'polygon(100% 0, 100% 100%, 0 100%)', false)}
          {renderDiagonalLine(CellType.IncDiag)}
        </div>
      );
    } 
    
    if (cell.type === CellType.DecDiag) {
      return (
        <div class="cell-content-layer">
          {renderHalf(Corner.TopRight, isWaterRight, isNoWaterRight, isBoatRight, isBlockRight, isNoBoatRight, isNoBoatWaterRight, 'polygon(0 0, 100% 0, 100% 100%)', isSurface)}
          {renderHalf(Corner.BottomLeft, isWaterLeft, isNoWaterLeft, isBoatLeft, isBlockLeft, isNoBoatLeft, isNoBoatWaterLeft, 'polygon(0 0, 100% 100%, 0 100%)', false)}
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

  const renderErrorOverlay = () => {
    if (!hasError) return null;
    if (cell.type === CellType.Single) {
      return (
        <div data-testid="cell-error" class="cell-error-overlay cell-error-single">
          <img src="/icons/error_single.png" alt="error" class="cell-error-img" />
        </div>
      );
    }
    if (cell.type === CellType.IncDiag) {
      const isTopLeft = errorCorner === Corner.TopLeft;
      return (
        <div 
          data-testid="cell-error" 
          class="cell-error-overlay"
          style={{
            clipPath: isTopLeft 
              ? 'polygon(0 0, 100% 0, 0 100%)' 
              : 'polygon(100% 0, 100% 100%, 0 100%)'
          }}
        >
          <img 
            src={isTopLeft ? '/icons/error_topleft.png' : '/icons/error_bottomright.png'} 
            alt="error" 
            class="cell-error-img" 
          />
        </div>
      );
    }
    if (cell.type === CellType.DecDiag) {
      const isTopRight = errorCorner === Corner.TopRight;
      return (
        <div 
          data-testid="cell-error" 
          class="cell-error-overlay"
          style={{
            clipPath: isTopRight 
              ? 'polygon(0 0, 100% 0, 100% 100%)' 
              : 'polygon(0 0, 0 100%, 100% 100%)'
          }}
        >
          <img 
            src={isTopRight ? '/icons/error_topright.png' : '/icons/error_bottomleft.png'} 
            alt="error" 
            class="cell-error-img" 
          />
        </div>
      );
    }
    return null;
  };

  return (
    <div 
      data-testid={`cell-${row}-${col}`}
      data-row={row}
      data-col={col}
      data-cell-type={cell.type}
      data-content-left={getContentName(cell.c_left)}
      data-content-right={getContentName(cell.c_right)}
      data-error={hasError ? "true" : undefined}
      class={`cell ${isBlock ? 'cell-block-bg' : ''} ${hasError ? 'cell-error-active' : ''}`}
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
      {renderErrorOverlay()}
      
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
