import { type LanguageSetting, setLanguage } from '../i18n';

export type LineInfoMode = 'none' | 'missing' | 'current';

export interface GameSettings {
  // Display
  language: LanguageSetting;
  dark_mode: boolean;
  show_bubbles: boolean;

  // Gameplay
  line_info: LineInfoMode;
  highlight_finished_row_col: boolean;
  highlight_grid: boolean; // Highlight hovered line
  show_grid_preview: boolean; // Show water preview
  hide_unknown: boolean; // Hide simple "?" hints
  progress_on_unknown: boolean; // Color "?" hints
  show_timer: boolean;
  skip_animations: boolean;

  // Accessibility
  bigger_hints_font: boolean;
  thicker_walls: boolean;

  // Controls
  drag_content: boolean; // Fill with drag
  invert_mouse: boolean; // Invert mouse buttons
  auto_flood_air: boolean; // Auto-flood air
}

export const DEFAULT_SETTINGS: GameSettings = {
  // Display
  language: 'system',
  dark_mode: true,
  show_bubbles: true,

  // Gameplay
  line_info: 'none',
  highlight_finished_row_col: true,
  highlight_grid: true,
  show_grid_preview: true,
  hide_unknown: false,
  progress_on_unknown: true,
  show_timer: true,
  skip_animations: false,

  // Accessibility
  bigger_hints_font: false,
  thicker_walls: false,

  // Controls
  drag_content: true,
  invert_mouse: false,
  auto_flood_air: false,
};

export const SETTINGS_STORAGE_KEY = 'liquidum_settings';

type SettingsListener = (settings: GameSettings) => void;
const listeners: Set<SettingsListener> = new Set();

export function getSettings(): GameSettings {
  try {
    if (typeof localStorage === 'undefined') {
      return { ...DEFAULT_SETTINGS };
    }
    const raw = localStorage.getItem(SETTINGS_STORAGE_KEY);
    if (!raw) {
      return { ...DEFAULT_SETTINGS };
    }
    const parsed = JSON.parse(raw);
    return { ...DEFAULT_SETTINGS, ...parsed };
  } catch {
    return { ...DEFAULT_SETTINGS };
  }
}

export function saveSettings(newSettings: Partial<GameSettings>): GameSettings {
  const current = getSettings();
  const updated: GameSettings = { ...current, ...newSettings };
  if (newSettings.language !== undefined) {
    setLanguage(updated.language);
  }
  try {
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem(SETTINGS_STORAGE_KEY, JSON.stringify(updated));
    }
  } catch (err) {
    console.error('Failed to save settings to localStorage', err);
  }
  listeners.forEach((listener) => listener(updated));
  return updated;
}

export function subscribeSettings(listener: SettingsListener): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

// Sync i18n language with current stored settings on startup
try {
  setLanguage(getSettings().language);
} catch {
  // Ignore in SSR / non-browser test environments
}
