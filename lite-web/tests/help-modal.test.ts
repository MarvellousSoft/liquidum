import { describe, it, expect } from 'vitest';
import { getActiveMechanicsForWeekday, ALL_MECHANICS } from '../src/components/HelpModal';

describe('HelpModal mechanics mapping', () => {
  it('contains all 7 core game mechanics', () => {
    expect(ALL_MECHANICS.length).toBe(7);
    const keys = ALL_MECHANICS.map((m) => m.key);
    expect(keys).toContain('aquariums');
    expect(keys).toContain('lineNumbers');
    expect(keys).toContain('boats');
    expect(keys).toContain('diagonals');
    expect(keys).toContain('aquariumHints');
    expect(keys).toContain('unknownHints');
    expect(keys).toContain('togetherSeparate');
  });

  it('maps Sunday (0) to Aquariums, Row/Col numbers, Diagonals, and Aquarium Hints', () => {
    const active = getActiveMechanicsForWeekday(0);
    expect(active.has('aquariums')).toBe(true);
    expect(active.has('lineNumbers')).toBe(true);
    expect(active.has('diagonals')).toBe(true);
    expect(active.has('aquariumHints')).toBe(true);
    expect(active.has('boats')).toBe(false);
    expect(active.has('unknownHints')).toBe(false);
  });

  it('maps Monday (1) to Basic rules (Aquariums and Row/Col numbers only)', () => {
    const active = getActiveMechanicsForWeekday(1);
    expect(active.has('aquariums')).toBe(true);
    expect(active.has('lineNumbers')).toBe(true);
    expect(active.has('boats')).toBe(false);
    expect(active.has('diagonals')).toBe(false);
    expect(active.has('unknownHints')).toBe(false);
  });

  it('maps Tuesday (2) to Boats and Unknown hints', () => {
    const active = getActiveMechanicsForWeekday(2);
    expect(active.has('boats')).toBe(true);
    expect(active.has('unknownHints')).toBe(true);
    expect(active.has('diagonals')).toBe(false);
  });

  it('maps Wednesday (3) to Diagonals and no hidden hints', () => {
    const active = getActiveMechanicsForWeekday(3);
    expect(active.has('diagonals')).toBe(true);
    expect(active.has('boats')).toBe(false);
    expect(active.has('unknownHints')).toBe(false);
  });

  it('maps Thursday (4) to Hidden water hints plus boats', () => {
    const active = getActiveMechanicsForWeekday(4);
    expect(active.has('boats')).toBe(true);
    expect(active.has('unknownHints')).toBe(true);
    expect(active.has('diagonals')).toBe(false);
  });

  it('maps Friday (5) to Freaky Friday (all rules active)', () => {
    const active = getActiveMechanicsForWeekday(5);
    expect(active.has('aquariums')).toBe(true);
    expect(active.has('lineNumbers')).toBe(true);
    expect(active.has('boats')).toBe(true);
    expect(active.has('diagonals')).toBe(true);
    expect(active.has('aquariumHints')).toBe(true);
    expect(active.has('unknownHints')).toBe(true);
    expect(active.has('togetherSeparate')).toBe(true);
  });

  it('maps Saturday (6) to One Row Saturday', () => {
    const active = getActiveMechanicsForWeekday(6);
    expect(active.has('aquariums')).toBe(true);
    expect(active.has('lineNumbers')).toBe(true);
    expect(active.has('boats')).toBe(false);
    expect(active.has('diagonals')).toBe(false);
  });
});
