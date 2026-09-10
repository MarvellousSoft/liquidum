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
  onPointerDown?: (row: number, col: number, corner: Corner, e: PointerEvent) => void;
  onPointerEnter?: (row: number, col: number, corner: Corner, e: PointerEvent) => void;
  onPointerUp?: (row: number, col: number, e: PointerEvent) => void;
}

export function Cell({ cell, row, col, hasBottomWall, hasRightWall, hasTopWall, hasLeftWall, isBlockTopNeighbor, isBlockBottomNeighbor, isBlockLeftNeighbor, isBlockRightNeighbor, isTopEdge, isLeftEdge, isBottomEdge, isRightEdge, onPointerDown, onPointerEnter, onPointerUp }: CellProps) {
  const isWaterLeft = cell.c_left === Content.Water;
  const isWaterRight = cell.c_right === Content.Water;
  
  const isNoWaterLeft = cell.c_left === Content.NoWater || cell.c_left === Content.NoBoatWater;
  const isNoWaterRight = cell.c_right === Content.NoWater || cell.c_right === Content.NoBoatWater;

  const isBoatLeft = cell.c_left === Content.Boat;
  const isBoatRight = cell.c_right === Content.Boat;
  
  const isBlockLeft = cell.c_left === Content.Block;
  const isBlockRight = cell.c_right === Content.Block;

  const renderHalf = (corner: Corner, isWater: boolean, isNoWater: boolean, isBoat: boolean, isBlock: boolean, clipPath?: string) => {
    let alignment = 'items-center justify-center';
    if (clipPath) {
      if (corner === Corner.TopLeft) alignment = 'items-start justify-start pl-0.5 pt-0.5 sm:pl-1 sm:pt-1';
      else if (corner === Corner.BottomRight) alignment = 'items-end justify-end pr-0.5 pb-0.5 sm:pr-1 sm:pb-1';
      else if (corner === Corner.TopRight) alignment = 'items-start justify-end pr-0.5 pt-0.5 sm:pr-1 sm:pt-1';
      else if (corner === Corner.BottomLeft) alignment = 'items-end justify-start pl-0.5 pb-0.5 sm:pl-1 sm:pb-1';
    }
  
    let content = null;
    // We don't render a background div for blocks anymore if the whole cell is a block,
    // we set it on the parent container. But for half-blocks (not possible in Liquidum currently, but safe):
    if (isBlock) content = <div class="absolute inset-0 bg-black z-10"></div>;
    else if (isWater) content = <div class="absolute inset-0 bg-[var(--cell-water)] border border-black/10"></div>;
    else if (isBoat) content = <div class={`absolute inset-0 flex ${alignment} text-base sm:text-xl`}>⛵</div>;
    else if (isNoWater) content = <div class={`absolute inset-0 flex ${alignment} text-[var(--text-secondary)] opacity-50 font-bold text-sm sm:text-base`}>✕</div>;
    
    if (!content) return null;
    return clipPath ? <div class="absolute inset-0" style={{ clipPath }}>{content}</div> : content;
  };

  const renderDiagonalLine = (type: CellType.IncDiag | CellType.DecDiag) => {
    const isInc = type === CellType.IncDiag;
    return (
      <svg class="absolute inset-0 w-full h-full pointer-events-none z-20 overflow-visible">
        <line
          x1={isInc ? "0%" : "0%"}
          y1={isInc ? "100%" : "0%"}
          x2={isInc ? "100%" : "100%"}
          y2={isInc ? "0%" : "100%"}
          stroke="black"
          stroke-width="3"
          stroke-linecap="round"
        />
      </svg>
    );
  };

  const renderContent = () => {
    if (cell.type === CellType.Single) {
      return renderHalf(Corner.TopLeft, isWaterLeft, isNoWaterLeft, isBoatLeft, isBlockLeft);
    } 
    
    if (cell.type === CellType.IncDiag) {
      // /
      const clipTopLeft = 'polygon(0 0, 100% 0, 0 100%)';
      const clipBottomRight = 'polygon(100% 0, 100% 100%, 0 100%)';
      return (
        <div class="absolute inset-0 pointer-events-none">
          {renderHalf(Corner.TopLeft, isWaterLeft, isNoWaterLeft, isBoatLeft, isBlockLeft, clipTopLeft)}
          {renderHalf(Corner.BottomRight, isWaterRight, isNoWaterRight, isBoatRight, isBlockRight, clipBottomRight)}
          {renderDiagonalLine(CellType.IncDiag)}
        </div>
      );
    }
    
    if (cell.type === CellType.DecDiag) {
      // \
      const clipTopRight = 'polygon(0 0, 100% 0, 100% 100%)';
      const clipBottomLeft = 'polygon(0 0, 100% 100%, 0 100%)';
      return (
        <div class="absolute inset-0 pointer-events-none">
          {renderHalf(Corner.TopRight, isWaterRight, isNoWaterRight, isBoatRight, isBlockRight, clipTopRight)}
          {renderHalf(Corner.BottomLeft, isWaterLeft, isNoWaterLeft, isBoatLeft, isBlockLeft, clipBottomLeft)}
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

  // If this cell is a block, it should be visually merged with neighbor blocks.
  const isBlock = cell.c_left === Content.Block && cell.type === CellType.Single;

  return (
    <div 
      class="relative w-8 h-8 sm:w-10 sm:h-10 md:w-12 md:h-12 cursor-pointer select-none"
      style={{ backgroundColor: isBlock ? '#000000' : 'var(--cell-bg)' }}
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
      {/* Faint Grid Lines (drawn under content) */}
      {!isRightEdge && !hasRightWall && <div class="absolute top-0 bottom-0 right-0 pointer-events-none" style={{ width: '1px', marginRight: '-0.5px', backgroundColor: 'rgba(255,255,255,0.08)' }} />}
      {!isBottomEdge && !hasBottomWall && <div class="absolute bottom-0 left-0 right-0 pointer-events-none" style={{ height: '1px', marginBottom: '-0.5px', backgroundColor: 'rgba(255,255,255,0.08)' }} />}

      {renderContent()}
      
      {/* Overlay Thick Walls. */}
      {(hasTopWall || isTopEdge) && <div class="absolute top-0 left-0 right-0 bg-black z-20 pointer-events-none" style={{ height: '3px', marginTop: isTopEdge ? '0px' : '-1.5px', marginLeft: isLeftEdge ? '0px' : '-1.5px', marginRight: isRightEdge ? '0px' : '-1.5px' }} />}
      {(hasBottomWall || isBottomEdge) && <div class="absolute bottom-0 left-0 right-0 bg-black z-20 pointer-events-none" style={{ height: '3px', marginBottom: isBottomEdge ? '0px' : '-1.5px', marginLeft: isLeftEdge ? '0px' : '-1.5px', marginRight: isRightEdge ? '0px' : '-1.5px' }} />}
      {(hasLeftWall || isLeftEdge) && <div class="absolute top-0 bottom-0 left-0 bg-black z-20 pointer-events-none" style={{ width: '3px', marginLeft: isLeftEdge ? '0px' : '-1.5px', marginTop: isTopEdge ? '0px' : '-1.5px', marginBottom: isBottomEdge ? '0px' : '-1.5px' }} />}
      {(hasRightWall || isRightEdge) && <div class="absolute top-0 bottom-0 right-0 bg-black z-20 pointer-events-none" style={{ width: '3px', marginRight: isRightEdge ? '0px' : '-1.5px', marginTop: isTopEdge ? '0px' : '-1.5px', marginBottom: isBottomEdge ? '0px' : '-1.5px' }} />}
    </div>
  );
}

