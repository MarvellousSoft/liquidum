import { RandomNumberGenerator } from "../model/RandomNumberGenerator";
import { consistent_hash } from "./RandomHub";

export const MAX_FLAIRS = 1000000;

export enum FlairId {
  Streak30 = 1,
  Insane100 = 2,
  MainCampaign = 3,
  Dlc = 4,
  MarvInc = 5,
  Functional = 6,
  SpeedRun = 7,
  ExtraIslandStart = 9000,
  Dev = 9999,
  ProStart = 10000,
}

export interface FlairInfo {
  id: number;
  extraFlairs: number;
  text: string;
  color: string;
  description: string;
}

const MONTH_NAMES = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
];

export function hsvToRgb(h: number, s: number, v: number): string {
  const i = Math.floor(h * 6);
  const f = h * 6 - i;
  const p = v * (1 - s);
  const q = v * (1 - f * s);
  const t = v * (1 - (1 - f) * s);
  let r = 0;
  let g = 0;
  let b = 0;
  switch (i % 6) {
    case 0:
      r = v;
      g = t;
      b = p;
      break;
    case 1:
      r = q;
      g = v;
      b = p;
      break;
    case 2:
      r = p;
      g = v;
      b = t;
      break;
    case 3:
      r = p;
      g = q;
      b = v;
      break;
    case 4:
      r = t;
      g = p;
      b = v;
      break;
    case 5:
      r = v;
      g = p;
      b = q;
      break;
  }
  const toHex = (n: number) =>
    Math.round(Math.max(0, Math.min(1, n)) * 255)
      .toString(16)
      .padStart(2, "0");
  return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
}

export function decodeFlairFromInt(
  num: number
): { id: number; extraFlairs: number } | null {
  if (num === -1 || num === undefined || num === null) {
    return null;
  }
  const id = num % MAX_FLAIRS;
  const extraFlairs = Math.floor(num / MAX_FLAIRS);
  return { id, extraFlairs };
}

export function encodeFlairToInt(id: number, extraFlairs: number = 0): number {
  if (id === -1) return -1;
  return extraFlairs * MAX_FLAIRS + id;
}

export function createFlair(
  id: number,
  extraFlairs: number = 0
): FlairInfo | null {
  if (id === -1 || id === undefined || id === null) {
    return null;
  }

  switch (id) {
    case FlairId.Dev:
      return {
        id,
        extraFlairs,
        text: "dev",
        color: "#ef4444",
        description: "Developer of Liquidum",
      };
    case FlairId.Streak30:
      return {
        id,
        extraFlairs,
        text: "30✓",
        color: "#ff4500",
        description: "Got a 30 daily streak",
      };
    case FlairId.Insane100:
      return {
        id,
        extraFlairs,
        text: "100",
        color: "#94a3b8",
        description: "Completed 100 insane levels",
      };
    case FlairId.MainCampaign:
      return {
        id,
        extraFlairs,
        text: "won",
        color: "#22c55e",
        description: "Completed all campaign levels",
      };
    case FlairId.Dlc:
      return {
        id,
        extraFlairs,
        text: "❤",
        color: "#ff69b4",
        description: "Purchased any Liquidum DLC. Thanks for the support! ❤",
      };
    case FlairId.MarvInc:
      return {
        id,
        extraFlairs,
        text: "inc",
        color: "#22c55e",
        description: "Purchased Marvellous Inc.",
      };
    case FlairId.Functional:
      return {
        id,
        extraFlairs,
        text: "λ",
        color: "#9ca3af",
        description: "Purchased functional",
      };
    case FlairId.SpeedRun:
      return {
        id,
        extraFlairs,
        text: "🏃",
        color: "#ef4444",
        description: "Submitted a run to speedrun.com",
      };
  }

  // Monthly pro flairs (10000+)
  if (id >= FlairId.ProStart) {
    const year = Math.floor((id - FlairId.ProStart) / 12) + 2024;
    const month = ((id - FlairId.ProStart + 1) % 12) + 1; // 1-based (Feb 2024 is id 10000)
    const monthName = MONTH_NAMES[month - 1] || `Month ${month}`;
    const rng = new RandomNumberGenerator();
    rng.set_seed(consistent_hash(`${month}-${year}`));
    const color = hsvToRgb(rng.randf(), 0.663, 0.804);
    return {
      id,
      extraFlairs,
      text: "pro",
      color,
      description: `Completed more than 15 dailies on ${monthName} ${year}`,
    };
  }

  // Extra island flairs (9001 - 9007)
  if (id > FlairId.ExtraIslandStart) {
    const section = id - FlairId.ExtraIslandStart;
    const extraFlairsMap: Record<number, { text: string; color?: string }> = {
      1: { text: "🤏" },
      2: { text: "🙏" },
      3: { text: "👄", color: "#fe2d86" },
      4: { text: "rock" },
      5: { text: "〰️", color: "#0068a8" },
      6: { text: "🪸", color: "#ff826a" },
      7: { text: "🔍", color: "#38bdf8" },
    };
    const entry = extraFlairsMap[section];
    if (entry) {
      let color = entry.color;
      if (!color) {
        const rng = new RandomNumberGenerator();
        rng.set_seed(consistent_hash(`extra-${section}`));
        color = hsvToRgb(rng.randf(), 0.663, 0.804);
      }
      return {
        id,
        extraFlairs,
        text: entry.text,
        color,
        description: `Completed island ${section}`,
      };
    }
  }

  return {
    id,
    extraFlairs,
    text: "★",
    color: "#38bdf8",
    description: `Special flair #${id}`,
  };
}
