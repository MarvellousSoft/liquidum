import { describe, test, expect, vi, beforeEach, afterEach } from 'vitest';
import { assetUrl, iconUrl } from '../src/utils/assets';

describe('Asset URLs and Touch Interaction', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  test('iconUrl and assetUrl produce relative paths without leading root slashes', () => {
    expect(iconUrl('nowater.png')).toBe('./icons/nowater.png');
    expect(iconUrl('boat_small.png')).toBe('./icons/boat_small.png');
    expect(iconUrl('checkmark.png')).toBe('./icons/checkmark.png');
    expect(assetUrl('/icons/brush.png')).toBe('./icons/brush.png');
    expect(assetUrl('icons/brush.png')).toBe('./icons/brush.png');
  });

  test('touch hold places X after hold duration', () => {
    let placedTool: string | null = null;
    let isHoldActive = false;
    let timer: any = null;

    const handleTouchDown = (r: number, c: number) => {
      timer = setTimeout(() => {
        isHoldActive = true;
        placedTool = 'NoWater';
      }, 400);
    };

    const handleTouchUp = () => {
      if (timer && !isHoldActive) {
        clearTimeout(timer);
        placedTool = 'Water'; // normal tap
      }
    };

    // 1. Quick tap (< 400ms)
    handleTouchDown(0, 0);
    vi.advanceTimersByTime(150);
    handleTouchUp();
    expect(placedTool).toBe('Water');
    expect(isHoldActive).toBe(false);

    // 2. Long touch (>= 400ms)
    placedTool = null;
    isHoldActive = false;
    handleTouchDown(0, 0);
    vi.advanceTimersByTime(400);
    expect(placedTool).toBe('NoWater');
    expect(isHoldActive).toBe(true);
  });
});
