/**
 * Utility to manage body scroll locking when modals are displayed.
 * Uses a reference counter so nested or multiple modals don't prematurely unlock the body.
 */
let openModalsCount = 0;

export function lockBodyScroll(): void {
  if (typeof document === 'undefined') return;
  openModalsCount++;
  if (openModalsCount === 1) {
    document.body.classList.add('modal-open');
    document.body.style.overflow = 'hidden';
    document.body.style.overscrollBehavior = 'none';
  }
}

export function unlockBodyScroll(): void {
  if (typeof document === 'undefined') return;
  openModalsCount = Math.max(0, openModalsCount - 1);
  if (openModalsCount === 0) {
    document.body.classList.remove('modal-open');
    document.body.style.overflow = '';
    document.body.style.overscrollBehavior = '';
  }
}
