import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { lockBodyScroll, unlockBodyScroll } from '../src/utils/scrollLock';

describe('scrollLock utility', () => {
  let mockBody: any;

  beforeEach(() => {
    const classListSet = new Set<string>();
    mockBody = {
      classList: {
        add: (cls: string) => classListSet.add(cls),
        remove: (cls: string) => classListSet.delete(cls),
        contains: (cls: string) => classListSet.has(cls),
      },
      style: {
        overflow: '',
        overscrollBehavior: '',
      },
    };
    (global as any).document = {
      body: mockBody,
    };
    // Ensure counter is reset
    while (mockBody.classList.contains('modal-open')) {
      unlockBodyScroll();
    }
  });

  afterEach(() => {
    while (mockBody.classList.contains('modal-open')) {
      unlockBodyScroll();
    }
    delete (global as any).document;
  });

  it('locks body scroll on first lock and restores on unlock', () => {
    expect(mockBody.classList.contains('modal-open')).toBe(false);
    expect(mockBody.style.overflow).toBe('');

    lockBodyScroll();
    expect(mockBody.classList.contains('modal-open')).toBe(true);
    expect(mockBody.style.overflow).toBe('hidden');
    expect(mockBody.style.overscrollBehavior).toBe('none');

    unlockBodyScroll();
    expect(mockBody.classList.contains('modal-open')).toBe(false);
    expect(mockBody.style.overflow).toBe('');
    expect(mockBody.style.overscrollBehavior).toBe('');
  });

  it('handles nested modal locks and unlocks in ref-counted order', () => {
    lockBodyScroll(); // modal 1 open
    expect(mockBody.classList.contains('modal-open')).toBe(true);

    lockBodyScroll(); // modal 2 open
    expect(mockBody.classList.contains('modal-open')).toBe(true);

    unlockBodyScroll(); // modal 2 close
    expect(mockBody.classList.contains('modal-open')).toBe(true);
    expect(mockBody.style.overflow).toBe('hidden');

    unlockBodyScroll(); // modal 1 close
    expect(mockBody.classList.contains('modal-open')).toBe(false);
    expect(mockBody.style.overflow).toBe('');
  });
});
