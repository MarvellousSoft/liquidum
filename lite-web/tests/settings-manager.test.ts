import { describe, it, expect, beforeEach, vi } from 'vitest';
import {
  getSettings,
  saveSettings,
  subscribeSettings,
  DEFAULT_SETTINGS,
  SETTINGS_STORAGE_KEY,
} from '../src/engine/SettingsManager';

class MockStorage implements Storage {
  private store: Record<string, string> = {};
  get length(): number { return Object.keys(this.store).length; }
  clear(): void { this.store = {}; }
  getItem(key: string): string | null { return this.store[key] ?? null; }
  key(index: number): string | null { return Object.keys(this.store)[index] ?? null; }
  removeItem(key: string): void { delete this.store[key]; }
  setItem(key: string, value: string): void { this.store[key] = value; }
}

describe('SettingsManager', () => {
  beforeEach(() => {
    globalThis.localStorage = new MockStorage();
  });

  it('returns default settings when localStorage is empty', () => {
    const settings = getSettings();
    expect(settings).toEqual(DEFAULT_SETTINGS);
  });


  it('saves partial settings and keeps defaults for unspecified keys', () => {
    const updated = saveSettings({ line_info: 'missing', thicker_walls: true });
    expect(updated.line_info).toBe('missing');
    expect(updated.thicker_walls).toBe(true);
    expect(updated.dark_mode).toBe(DEFAULT_SETTINGS.dark_mode);

    const retrieved = getSettings();
    expect(retrieved.line_info).toBe('missing');
    expect(retrieved.thicker_walls).toBe(true);
  });

  it('notifies subscribers on saveSettings', () => {
    const listener = vi.fn();
    const unsubscribe = subscribeSettings(listener);

    saveSettings({ bigger_hints_font: true });
    expect(listener).toHaveBeenCalledWith(expect.objectContaining({ bigger_hints_font: true }));

    unsubscribe();
    saveSettings({ bigger_hints_font: false });
    expect(listener).toHaveBeenCalledTimes(1);
  });
});
