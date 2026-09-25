import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import {
  t,
  setLanguage,
  detectBrowserLanguage,
  resolveLanguage,
  SUPPORTED_LANGUAGES,
} from '../src/i18n';
import en from '../src/i18n/locales/en.json';
import pt_BR from '../src/i18n/locales/pt_BR.json';
import { getHintHoverText, HintType } from '../src/model/GridData';

describe('i18n Locale Bundles Parity', () => {
  function getAllKeys(obj: any, prefix = ''): string[] {
    let keys: string[] = [];
    for (const key of Object.keys(obj)) {
      const fullKey = prefix ? `${prefix}.${key}` : key;
      if (typeof obj[key] === 'object' && obj[key] !== null) {
        keys = keys.concat(getAllKeys(obj[key], fullKey));
      } else {
        keys.push(fullKey);
      }
    }
    return keys.sort();
  }

  it('has identical keys in en.json and pt_BR.json', () => {
    const enKeys = getAllKeys(en);
    const ptKeys = getAllKeys(pt_BR);

    const missingInPt = enKeys.filter((k) => !ptKeys.includes(k));
    const missingInEn = ptKeys.filter((k) => !enKeys.includes(k));

    expect(missingInPt, `Keys missing in pt_BR: ${missingInPt.join(', ')}`).toEqual([]);
    expect(missingInEn, `Keys missing in en: ${missingInEn.join(', ')}`).toEqual([]);
  });
});

describe('Browser Language Detection', () => {
  const originalNavigator = globalThis.navigator;

  afterEach(() => {
    Object.defineProperty(globalThis, 'navigator', {
      value: originalNavigator,
      configurable: true,
      writable: true,
    });
  });

  it('detects pt-BR when navigator.languages starts with pt-BR', () => {
    Object.defineProperty(globalThis, 'navigator', {
      value: { languages: ['pt-BR', 'en-US', 'en'], language: 'pt-BR' },
      configurable: true,
      writable: true,
    });
    expect(detectBrowserLanguage()).toBe('pt-BR');
  });

  it('detects pt-BR when navigator.languages starts with generic pt', () => {
    Object.defineProperty(globalThis, 'navigator', {
      value: { languages: ['pt', 'en'], language: 'pt' },
      configurable: true,
      writable: true,
    });
    expect(detectBrowserLanguage()).toBe('pt-BR');
  });

  it('detects en when navigator.languages is English', () => {
    Object.defineProperty(globalThis, 'navigator', {
      value: { languages: ['en-US', 'en'], language: 'en-US' },
      configurable: true,
      writable: true,
    });
    expect(detectBrowserLanguage()).toBe('en');
  });

  it('falls back to en for unsupported languages like French', () => {
    Object.defineProperty(globalThis, 'navigator', {
      value: { languages: ['fr-FR', 'fr'], language: 'fr-FR' },
      configurable: true,
      writable: true,
    });
    expect(detectBrowserLanguage()).toBe('en');
  });
});

describe('resolveLanguage and setLanguage', () => {
  it('resolves explicit languages correctly', () => {
    expect(resolveLanguage('en')).toBe('en');
    expect(resolveLanguage('pt-BR')).toBe('pt-BR');
  });

  it('changes active language dynamically and translates keys', () => {
    setLanguage('en');
    expect(t('toolbar.water')).toBe('Water');
    expect(t('toolbar.undo')).toBe('Undo');
    expect(t('settings.title')).toBe('Settings');

    setLanguage('pt-BR');
    expect(t('toolbar.water')).toBe('Água');
    expect(t('toolbar.undo')).toBe('Desfazer');
    expect(t('settings.title')).toBe('Opções');

    // Switch back to English
    setLanguage('en');
    expect(t('toolbar.water')).toBe('Water');
  });

  it('localizes getHintHoverText according to active language', () => {
    setLanguage('en');
    expect(getHintHoverText(0, HintType.Zero, true, true)).toBe('There are no water cells in this row.');
    expect(getHintHoverText(1, HintType.Together, false, false)).toBe('There is 1 boat in this column.');

    setLanguage('pt-BR');
    expect(getHintHoverText(0, HintType.Zero, true, true)).toBe('Não há células de água nesta linha.');
    expect(getHintHoverText(1, HintType.Together, false, false)).toBe('Há 1 barco nesta coluna.');

    // Cleanup
    setLanguage('en');
  });
});
