import i18next from 'i18next';
import { useState, useEffect } from 'preact/hooks';
import en from './locales/en.json';
import pt_BR from './locales/pt_BR.json';

export type LanguageCode = 'en' | 'pt-BR';
export type LanguageSetting = 'system' | LanguageCode;

/**
 * Detect language from browser locale / info.
 * Inspects navigator.languages and navigator.language.
 * Returns 'pt-BR' if Portuguese is preferred, otherwise 'en'.
 */
export function detectBrowserLanguage(): LanguageCode {
  if (typeof navigator !== 'undefined') {
    const candidateList = navigator.languages || [navigator.language || ''];
    for (const lang of candidateList) {
      if (typeof lang === 'string' && lang.toLowerCase().startsWith('pt')) {
        return 'pt-BR';
      }
    }
  }
  return 'en';
}

/**
 * Resolves a LanguageSetting ('system' | 'en' | 'pt-BR') to an active LanguageCode.
 */
export function resolveLanguage(setting: LanguageSetting): LanguageCode {
  if (setting === 'system') {
    return detectBrowserLanguage();
  }
  return setting === 'pt-BR' ? 'pt-BR' : 'en';
}

// Initialize i18next synchronously with embedded resources
if (!i18next.isInitialized) {
  i18next.init({
    lng: detectBrowserLanguage(),
    fallbackLng: 'en',
    resources: {
      en: { translation: en },
      'pt-BR': { translation: pt_BR },
    },
    interpolation: {
      escapeValue: false, // Preact natively escapes
    },
  });
}

/**
 * Set active language setting.
 */
export function setLanguage(setting: LanguageSetting): void {
  const resolved = resolveLanguage(setting);
  if (i18next.language !== resolved) {
    i18next.changeLanguage(resolved);
  }
}

/**
 * Preact hook that provides translation function and re-renders on language change.
 */
export function useTranslation() {
  const [lang, setLang] = useState(i18next.language);

  useEffect(() => {
    const handleLanguageChanged = (newLang: string) => {
      setLang(newLang);
    };
    i18next.on('languageChanged', handleLanguageChanged);
    return () => {
      i18next.off('languageChanged', handleLanguageChanged);
    };
  }, []);

  return {
    t: i18next.t.bind(i18next),
    i18n: i18next,
    language: lang as LanguageCode,
  };
}

/**
 * Direct translator function for utilities and non-component logic.
 */
export const t = i18next.t.bind(i18next);
export default i18next;
