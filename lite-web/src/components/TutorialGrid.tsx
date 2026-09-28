import { h } from 'preact';
import { iconUrl } from '../utils/assets';

export type MiniCellType =
  | 'water'
  | 'air'
  | 'boat'
  | 'empty'
  | 'water-diag-inc' // / (bottom-right water)
  | 'water-diag-dec' // \ (bottom-left water)
  | 'water-diag-inc-top' // / (top-left water)
  | 'water-diag-dec-top'; // \ (top-right water)

export interface TutorialGridProps {
  cells: MiniCellType[][];
  hints?: (string | null)[]; // length should match rows for row hints, or columns for col hints (assumes 1D line hints for simplicity)
  isRowHint?: boolean;
  status: 'valid' | 'invalid';
  wallRight?: boolean[][];
  wallBottom?: boolean[][];
  cellHints?: (string | null)[][];
  iconPosition?: 'right' | 'bottom';
}

export function TutorialGrid({ cells, hints, isRowHint = true, status, wallRight, wallBottom, cellHints, iconPosition = 'right' }: TutorialGridProps) {
  const rows = cells.length;
  const cols = rows > 0 ? cells[0].length : 0;

  return (
    <div class={`flex ${iconPosition === 'right' ? 'flex-row' : 'flex-col'} items-center gap-2`} data-testid={`tutorial-grid-${status}`}>
      <div class={`flex ${isRowHint ? 'flex-row' : 'flex-col'} items-center gap-1`}>
        {/* Render Hints (if row hint, on the left, if col hint, on the top) */}
        {isRowHint && hints && (
          <div class="flex flex-col gap-0.5 mr-0.5">
            {hints.map((h, i) => (
              <div
                key={i}
                class="w-[24px] h-[24px] flex items-center justify-center font-bold text-[14px] godot-text-outline"
                style={{ color: 'var(--hint-normal)' }}
              >
                {h || ''}
              </div>
            ))}
          </div>
        )}

        {!isRowHint && hints && (
          <div class="flex flex-row gap-0.5 mb-0.5">
            {hints.map((h, i) => (
              <div
                key={i}
                class="w-[24px] h-[24px] flex items-center justify-center font-bold text-[14px] godot-text-outline"
                style={{ color: 'var(--hint-normal)' }}
              >
                {h || ''}
              </div>
            ))}
          </div>
        )}

        {/* Render Grid */}
        <div
          class="border-[3px] rounded-sm flex flex-col"
          style={{ borderColor: 'var(--cell-wall)' }}
        >
          {cells.map((row, rIdx) => (
            <div key={rIdx} class="flex flex-row">
              {row.map((cell, cIdx) => {
                let bg = 'var(--cell-bg)';
                let content = null;
                let clipPath = undefined;

                if (cell === 'water') bg = 'var(--cell-water)';
                if (cell === 'air') content = <img src={iconUrl('nowater.png')} class="w-full h-full opacity-60" />;
                if (cell === 'boat') {
                  bg = 'var(--cell-bg)';
                  content = <img src={iconUrl('boat_small.png')} class="w-[85%] h-[85%] drop-shadow-md" />;
                }

                if (cell === 'water-diag-inc') {
                  // Bottom right is water
                  content = (
                    <>
                      <div class="absolute inset-0" style={{ backgroundColor: 'var(--cell-water)', clipPath: 'polygon(100% 0, 100% 100%, 0 100%)' }} />
                      <svg class="absolute inset-0 w-full h-full"><line x1="0%" y1="100%" x2="100%" y2="0%" stroke="var(--cell-wall)" stroke-width="3" /></svg>
                    </>
                  );
                } else if (cell === 'water-diag-inc-top') {
                  // Top left is water
                  content = (
                    <>
                      <div class="absolute inset-0" style={{ backgroundColor: 'var(--cell-water)', clipPath: 'polygon(0 0, 100% 0, 0 100%)' }} />
                      <svg class="absolute inset-0 w-full h-full"><line x1="0%" y1="100%" x2="100%" y2="0%" stroke="var(--cell-wall)" stroke-width="3" /></svg>
                    </>
                  );
                } else if (cell === 'water-diag-dec') {
                  // Bottom left is water
                  content = (
                    <>
                      <div class="absolute inset-0" style={{ backgroundColor: 'var(--cell-water)', clipPath: 'polygon(0 0, 0 100%, 100% 100%)' }} />
                      <svg class="absolute inset-0 w-full h-full"><line x1="0%" y1="0%" x2="100%" y2="100%" stroke="var(--cell-wall)" stroke-width="3" /></svg>
                    </>
                  );
                } else if (cell === 'water-diag-dec-top') {
                  // Top right is water
                  content = (
                    <>
                      <div class="absolute inset-0" style={{ backgroundColor: 'var(--cell-water)', clipPath: 'polygon(0 0, 100% 0, 100% 100%)' }} />
                      <svg class="absolute inset-0 w-full h-full"><line x1="0%" y1="0%" x2="100%" y2="100%" stroke="var(--cell-wall)" stroke-width="3" /></svg>
                    </>
                  );
                }

                const cHint = cellHints?.[rIdx]?.[cIdx];
                const hasWallRight = wallRight?.[rIdx]?.[cIdx];
                const hasWallBottom = wallBottom?.[rIdx]?.[cIdx];

                const isLastRow = rIdx === rows - 1;
                const isLastCol = cIdx === cols - 1;

                const rightBorder = isLastCol ? 'none' : '1px dashed var(--cell-border)';
                const bottomBorder = isLastRow ? 'none' : '1px dashed var(--cell-border)';

                return (
                  <div
                    key={cIdx}
                    class="w-[24px] h-[24px] flex items-center justify-center relative"
                    style={{
                      backgroundColor: bg,
                      borderRight: rightBorder,
                      borderBottom: bottomBorder,
                      boxSizing: 'content-box'
                    }}
                  >
                    {content}
                    {hasWallRight && !isLastCol && <div class="cell-wall cell-wall-right" />}
                    {hasWallBottom && !isLastRow && <div class="cell-wall cell-wall-bottom" />}
                    {cHint && (
                      <div class="absolute inset-0 flex items-center justify-center font-bold text-[12px] pointer-events-none godot-text-outline" style={{ color: 'var(--hint-normal)', zIndex: 10 }}>
                        {cHint}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          ))}
        </div>
      </div>

      {/* Status Icon */}
      <div class={`text-[14px] font-bold shrink-0 ${status === 'valid' ? 'text-green-400' : 'text-red-400'}`}>
        {status === 'valid' ? '✅' : '❌'}
      </div>
    </div>
  );
}
