import { describe, it, expect, beforeEach } from "vitest";
import i18next from "../src/i18n";
import { generateDailyShareText } from "../src/engine/DailyLevel";

// 2026-09-29 is a Tuesday
const TUESDAY_DATE = "2026-09-29";

describe("generateDailyShareText – localization", () => {
  describe("English", () => {
    beforeEach(async () => {
      await i18next.changeLanguage("en");
    });

    it("generates correct share text for a Tuesday", () => {
      const text = generateDailyShareText({
        dateStr: TUESDAY_DATE,
        seconds: 185, // 03:05
        mistakes: 1,
        t: i18next.t.bind(i18next),
      });

      expect(text).toContain("I won #liquidum daily on 2026-09-29");
      expect(text).toContain("⛵ Secret Boat Tuesday");
      expect(text).toContain("🕑 03:05");
      expect(text).toContain("❌ 1 mistake");
      expect(text).toContain("linktr.ee/liquidum");
    });

    it("uses plural 'mistakes' for multiple mistakes", () => {
      const text = generateDailyShareText({
        dateStr: TUESDAY_DATE,
        seconds: 60,
        mistakes: 3,
        t: i18next.t.bind(i18next),
      });
      expect(text).toContain("❌ 3 mistakes");
    });

    it("shows trophy for zero mistakes", () => {
      const text = generateDailyShareText({
        dateStr: TUESDAY_DATE,
        seconds: 90,
        mistakes: 0,
        t: i18next.t.bind(i18next),
      });
      expect(text).toContain("🏆 0 mistakes");
    });
  });

  describe("pt-BR", () => {
    beforeEach(async () => {
      await i18next.changeLanguage("pt-BR");
    });

    it("generates correct share text for a Tuesday", () => {
      const text = generateDailyShareText({
        dateStr: TUESDAY_DATE,
        seconds: 185, // 03:05
        mistakes: 1,
        t: i18next.t.bind(i18next),
      });

      expect(text).toContain("Ganhei o #liquidum diário de 2026-09-29");
      expect(text).toContain("⛵ Terça Naval Secreta");
      expect(text).toContain("🕑 03:05");
      expect(text).toContain("❌ 1 erro");
      expect(text).toContain("linktr.ee/liquidum");
    });

    it("uses plural 'erros' for multiple mistakes", () => {
      const text = generateDailyShareText({
        dateStr: TUESDAY_DATE,
        seconds: 60,
        mistakes: 3,
        t: i18next.t.bind(i18next),
      });
      expect(text).toContain("❌ 3 erros");
    });

    it("shows trophy for zero mistakes", () => {
      const text = generateDailyShareText({
        dateStr: TUESDAY_DATE,
        seconds: 90,
        mistakes: 0,
        t: i18next.t.bind(i18next),
      });
      expect(text).toContain("🏆 0 erros");
    });
  });
});
