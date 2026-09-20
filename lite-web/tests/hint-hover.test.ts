import { describe, it, expect } from 'vitest';
import { getHintHoverText, HintType } from '../src/model/GridData';

describe('getHintHoverText', () => {
  describe('Water Hints - Row', () => {
    it('handles known counts in row', () => {
      expect(getHintHoverText(4, HintType.Hidden, true, true)).toBe('There are 4 water cells in this row.');
      expect(getHintHoverText(1, HintType.Hidden, true, true)).toBe('There is 1 water cell in this row.');
      expect(getHintHoverText(0, HintType.Hidden, true, true)).toBe('There are no water cells in this row.');
      expect(getHintHoverText(0, HintType.Zero, true, true)).toBe('There are no water cells in this row.');
      expect(getHintHoverText(2.5, HintType.Hidden, true, true)).toBe('There are 2.5 water cells in this row.');
    });

    it('handles together hints in row', () => {
      expect(getHintHoverText(-1, HintType.Together, true, true)).toBe('The water cells in this row are contiguous.');
      expect(getHintHoverText(4, HintType.Together, true, true)).toBe('There are 4 water cells in this row. They are contiguous.');
      expect(getHintHoverText(1, HintType.Together, true, true)).toBe('There is 1 water cell in this row. It is contiguous.');
    });

    it('handles separated hints in row', () => {
      expect(getHintHoverText(-1, HintType.Separated, true, true)).toBe('The water cells in this row are not contiguous.');
      expect(getHintHoverText(2, HintType.Separated, true, true)).toBe('There are 2 water cells in this row. They are not contiguous.');
      expect(getHintHoverText(3, HintType.Separated, true, true)).toBe('There are 3 water cells in this row. They are not contiguous.');
    });

    it('handles unknown hints in row', () => {
      expect(getHintHoverText(-1, HintType.Hidden, true, true)).toBe('There is an unknown number of water cells in this row.');
    });
  });

  describe('Water Hints - Column', () => {
    it('handles known counts in column', () => {
      expect(getHintHoverText(4, HintType.Hidden, true, false)).toBe('There are 4 water cells in this column.');
      expect(getHintHoverText(1, HintType.Hidden, true, false)).toBe('There is 1 water cell in this column.');
      expect(getHintHoverText(0, HintType.Hidden, true, false)).toBe('There are no water cells in this column.');
    });

    it('handles together hints in column', () => {
      expect(getHintHoverText(-1, HintType.Together, true, false)).toBe('The water cells in this column are contiguous.');
      expect(getHintHoverText(2, HintType.Together, true, false)).toBe('There are 2 water cells in this column. They are contiguous.');
    });

    it('handles separated hints in column', () => {
      expect(getHintHoverText(-1, HintType.Separated, true, false)).toBe('The water cells in this column are not contiguous.');
      expect(getHintHoverText(2, HintType.Separated, true, false)).toBe('There are 2 water cells in this column. They are not contiguous.');
      expect(getHintHoverText(3, HintType.Separated, true, false)).toBe('There are 3 water cells in this column. They are not contiguous.');
    });

    it('handles unknown hints in column', () => {
      expect(getHintHoverText(-1, HintType.Hidden, true, false)).toBe('There is an unknown number of water cells in this column.');
    });
  });

  describe('Boat Hints', () => {
    it('handles boat counts in row and column', () => {
      expect(getHintHoverText(0, HintType.Hidden, false, true)).toBe('There are no boats in this row.');
      expect(getHintHoverText(1, HintType.Hidden, false, true)).toBe('There is 1 boat in this row.');
      expect(getHintHoverText(2, HintType.Hidden, false, true)).toBe('There are 2 boats in this row.');
      expect(getHintHoverText(0, HintType.Hidden, false, false)).toBe('There are no boats in this column.');
      expect(getHintHoverText(1, HintType.Hidden, false, false)).toBe('There is 1 boat in this column.');
      expect(getHintHoverText(2, HintType.Hidden, false, false)).toBe('There are 2 boats in this column.');
    });

    it('handles boat together and separated hints', () => {
      expect(getHintHoverText(-1, HintType.Together, false, true)).toBe('The boats in this row are contiguous.');
      expect(getHintHoverText(-1, HintType.Separated, false, true)).toBe('The boats in this row are not contiguous.');
      expect(getHintHoverText(2, HintType.Together, false, true)).toBe('There are 2 boats in this row. They are contiguous.');
      expect(getHintHoverText(2, HintType.Separated, false, true)).toBe('There are 2 boats in this row. They are not contiguous.');
      expect(getHintHoverText(-1, HintType.Hidden, false, true)).toBe('There is an unknown number of boats in this row.');
    });
  });
});
