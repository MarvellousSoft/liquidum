import { PlayFab, PlayFabClient } from "playfab-sdk";
import { getGeneratedName } from "./NameGenerator";

export const PLAYFAB_TITLE_ID = "3D3A0";
export const DAILY_STATISTIC_NAME = "daily";
export const BASE_DAILY_DATE_UTC = Date.UTC(2024, 3, 16); // 2024-04-16 00:00:00 UTC

export interface LeaderboardEntry {
  position: number; // 1-indexed rank
  playFabId: string;
  displayName: string;
  avatarUrl?: string | null;
  seconds: number;
  mistakes: number;
  rawScore: number;
  isCurrentUser: boolean;
}

export interface LoginResultInfo {
  playFabId: string;
  displayName: string;
  avatarUrl?: string | null;
  newlyCreated: boolean;
}

export interface SubmitScoreResult {
  submitted: boolean;
  reason?: "already_submitted" | "error";
  error?: any;
}

/**
 * Computes the daily statistic version according to Liquidum's formula:
 * (day_unix - "2024-04-16") / 86400
 */
export function getDailyLeaderboardVersion(dateInput?: string | Date): number {
  let dateUtcMs: number;
  if (!dateInput) {
    const now = new Date();
    dateUtcMs = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  } else if (typeof dateInput === "string") {
    const match = dateInput.match(/^(\d{4})-(\d{2})-(\d{2})/);
    if (match) {
      dateUtcMs = Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
    } else {
      const d = new Date(dateInput);
      dateUtcMs = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
    }
  } else {
    dateUtcMs = Date.UTC(dateInput.getUTCFullYear(), dateInput.getUTCMonth(), dateInput.getUTCDate());
  }
  return Math.floor((dateUtcMs - BASE_DAILY_DATE_UTC) / (86400 * 1000));
}

/**
 * Returns a YYYY-MM-DD date string with an optional UTC day offset (e.g. 0 for today, -1 for yesterday).
 */
export function getDateStringForOffset(daysOffset: number = 0): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + daysOffset);
  const year = d.getUTCFullYear();
  const month = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

/**
 * Liquidum encodes time and mistakes into a single negative integer:
 * -1 * (min(seconds, 99999) + min(mistakes, 1000) * 100000)
 */
export function encodeDailyScore(seconds: number, mistakes: number): number {
  const clampedSecs = Math.max(0, Math.min(Math.floor(seconds), 99999));
  const clampedMistakes = Math.max(0, Math.min(Math.floor(mistakes), 1000));
  return -1 * (clampedSecs + clampedMistakes * 100000);
}

/**
 * Decodes the score into mistakes and seconds.
 */
export function decodeDailyScore(encodedScore: number): { seconds: number; mistakes: number } {
  const raw = Math.abs(encodedScore);
  const mistakes = Math.floor(raw / 100000);
  const seconds = raw % 100000;
  return { seconds, mistakes };
}

/**
 * Retrieves or generates a persistent anonymous UUID for browser login.
 */
export function getOrCreateCustomId(storage?: Storage): string {
  const store = storage || (typeof localStorage !== "undefined" ? localStorage : null);
  const KEY = "liquidum_custom_id";
  let id = store ? store.getItem(KEY) : null;
  if (!id) {
    if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
      id = crypto.randomUUID();
    } else {
      id = "web_" + Math.random().toString(36).substring(2, 15) + Date.now().toString(36);
    }
    if (store) {
      store.setItem(KEY, id);
    }
  }
  return id;
}

export function isDailyScoreSubmitted(version: number, storage?: Storage): boolean {
  const store = storage || (typeof localStorage !== "undefined" ? localStorage : null);
  if (!store) return false;
  return store.getItem(`liquidum_daily_submitted_${version}`) === "true";
}

export function markDailyScoreSubmitted(version: number, storage?: Storage): void {
  const store = storage || (typeof localStorage !== "undefined" ? localStorage : null);
  if (store) {
    store.setItem(`liquidum_daily_submitted_${version}`, "true");
  }
}

/**
 * Extracts display name matching Godot's PlayfabIntegration.gd:
 * 1. profile.DisplayName if non-empty
 * 2. profile.LinkedAccounts[].Username if non-empty
 * 3. Deterministic generated name via NameGenerator.get_name(rng, playFabId)
 */
export function extractDisplayNameFromProfile(
  profile: any,
  playFabId: string,
  fallbackDisplayName?: string
): string {
  if (profile) {
    if (profile.DisplayName && typeof profile.DisplayName === "string" && profile.DisplayName.trim() !== "") {
      return profile.DisplayName.trim();
    }
    if (Array.isArray(profile.LinkedAccounts)) {
      for (const acc of profile.LinkedAccounts) {
        if (acc && acc.Username && typeof acc.Username === "string" && acc.Username.trim() !== "") {
          return acc.Username.trim();
        }
      }
    }
  }
  if (fallbackDisplayName && typeof fallbackDisplayName === "string" && fallbackDisplayName.trim() !== "") {
    return fallbackDisplayName.trim();
  }
  return getGeneratedName(String(playFabId || ""));
}

/**
 * Extracts avatar URL matching Godot's PlayfabIntegration.gd:
 * profile.AvatarUrl if present
 */
export function extractAvatarUrlFromProfile(profile: any): string | null {
  if (profile && profile.AvatarUrl && typeof profile.AvatarUrl === "string" && profile.AvatarUrl.trim() !== "") {
    return profile.AvatarUrl.trim();
  }
  return null;
}

/**
 * Adapts PlayFab.MakeRequest to use global fetch instead of Node https.
 */
export function setupPlayFabFetchAdapter(): void {
  PlayFab.settings.titleId = PLAYFAB_TITLE_ID;

  (PlayFab as any).MakeRequest = function (
    urlStr: string,
    request: any,
    authType: string | null,
    authValue: string | null,
    callback?: (error: any, result: any) => void
  ) {
    const headers: Record<string, string> = {
      "Content-Type": "application/json",
      "X-PlayFabSDK": "NodeSDK-" + ((PlayFab as any).sdk_version || "2.187.251205"),
    };
    if (authType && authValue) {
      headers[authType] = authValue;
    }

    fetch(urlStr, {
      method: "POST",
      headers,
      body: JSON.stringify(request || {}),
    })
      .then(async (res) => {
        const text = await res.text();
        let envelope: any = null;
        try {
          envelope = JSON.parse(text);
        } catch {
          envelope = {
            code: res.status,
            status: res.statusText,
            error: "JSON Parse error",
            errorMessage: text,
          };
        }

        if (res.ok && envelope && envelope.code === 200) {
          if (callback) callback(null, envelope);
        } else {
          if (callback) callback(envelope || { code: res.status, error: "HttpError" }, null);
        }
      })
      .catch((err) => {
        if (callback) {
          callback({ code: 0, status: "NetworkError", error: String(err) }, null);
        }
      });
  };
}

// Automatically setup adapter when module is loaded
setupPlayFabFetchAdapter();

export class PlayFabService {
  private currentPlayFabId: string | null = null;
  private currentDisplayName: string | null = null;
  private currentAvatarUrl: string | null = null;
  private loginPromise: Promise<LoginResultInfo> | null = null;
  private storage: Storage | null = null;

  constructor(storage?: Storage) {
    this.storage = storage || (typeof localStorage !== "undefined" ? localStorage : null);
  }

  public setStorage(storage: Storage | null) {
    this.storage = storage;
  }

  public getPlayFabId(): string | null {
    return this.currentPlayFabId;
  }

  public getDisplayName(): string | null {
    return this.currentDisplayName;
  }

  public getAvatarUrl(): string | null {
    return this.currentAvatarUrl;
  }

  public isLoggedIn(): boolean {
    return PlayFabClient.IsClientLoggedIn() && Boolean(this.currentPlayFabId);
  }

  /**
   * Logs in anonymously using CustomID. Caches the SessionTicket inside PlayFab SDK.
   */
  public async login(customId?: string): Promise<LoginResultInfo> {
    if (this.isLoggedIn() && !customId) {
      return {
        playFabId: this.currentPlayFabId!,
        displayName: this.currentDisplayName || "Anonymous",
        avatarUrl: this.currentAvatarUrl,
        newlyCreated: false,
      };
    }

    if (this.loginPromise && !customId) {
      return this.loginPromise;
    }

    const effectiveCustomId = customId || getOrCreateCustomId(this.storage || undefined);

    this.loginPromise = new Promise<LoginResultInfo>((resolve, reject) => {
      PlayFab.settings.titleId = PLAYFAB_TITLE_ID;

      const request = {
        TitleId: PLAYFAB_TITLE_ID,
        CustomId: effectiveCustomId,
        CreateAccount: true,
        InfoRequestParameters: {
          GetPlayerProfile: true,
          ProfileConstraints: {
            ShowLinkedAccounts: true,
            ShowAvatarUrl: true,
            ShowDisplayName: true,
          },
        },
      };

      PlayFabClient.LoginWithCustomID(request as any, (error, result) => {
        if (error || !result || result.code !== 200) {
          this.loginPromise = null;
          return reject(error || new Error("PlayFab Login failed"));
        }

        const data = result.data;
        this.currentPlayFabId = data.PlayFabId ?? null;
        const profile = data.InfoResultPayload?.PlayerProfile;
        this.currentDisplayName = extractDisplayNameFromProfile(profile, this.currentPlayFabId || "");
        this.currentAvatarUrl = extractAvatarUrlFromProfile(profile);

        resolve({
          playFabId: this.currentPlayFabId || "",
          displayName: this.currentDisplayName,
          avatarUrl: this.currentAvatarUrl,
          newlyCreated: Boolean(data.NewlyCreated),
        });
      });
    });

    return this.loginPromise;
  }

  /**
   * Fetches the leaderboard for a given version.
   * If version is omitted, fetches the current daily version.
   */
  public async getLeaderboard(version?: number, maxResults: number = 100): Promise<LeaderboardEntry[]> {
    await this.login();

    const targetVersion = version !== undefined ? version : getDailyLeaderboardVersion();

    return new Promise<LeaderboardEntry[]>((resolve, reject) => {
      const request: any = {
        StatisticName: DAILY_STATISTIC_NAME,
        StartPosition: 0,
        MaxResultsCount: Math.min(maxResults, 100),
        ProfileConstraints: {
          ShowLinkedAccounts: true,
          ShowAvatarUrl: true,
          ShowDisplayName: true,
        },
      };

      if (targetVersion >= 0) {
        request.Version = targetVersion;
      }

      PlayFabClient.GetLeaderboard(request, (error, result) => {
        if (error || !result || result.code !== 200) {
          return reject(error || new Error("Failed to fetch leaderboard"));
        }

        const rawList = result.data?.Leaderboard || [];
        const entries: LeaderboardEntry[] = rawList.map((item: any) => {
          const { seconds, mistakes } = decodeDailyScore(item.StatValue);
          const profile = item.Profile;
          const displayName = extractDisplayNameFromProfile(profile, item.PlayFabId, item.DisplayName);
          const avatarUrl = extractAvatarUrlFromProfile(profile);

          return {
            position: item.Position + 1, // 1-based rank
            playFabId: item.PlayFabId,
            displayName,
            avatarUrl,
            seconds,
            mistakes,
            rawScore: item.StatValue,
            isCurrentUser: item.PlayFabId === this.currentPlayFabId,
          };
        });

        resolve(entries);
      });
    });
  }

  /**
   * Submits daily score for the very first completion only.
   * Subsequent calls for the same version will be skipped.
   */
  public async submitDailyScore(
    seconds: number,
    mistakes: number,
    dateOrVersion?: string | number
  ): Promise<SubmitScoreResult> {
    const version =
      typeof dateOrVersion === "number"
        ? dateOrVersion
        : getDailyLeaderboardVersion(dateOrVersion);

    if (isDailyScoreSubmitted(version, this.storage || undefined)) {
      return { submitted: false, reason: "already_submitted" };
    }

    await this.login();

    const encodedValue = encodeDailyScore(seconds, mistakes);

    return new Promise<SubmitScoreResult>((resolve) => {
      const request = {
        Statistics: [
          {
            StatisticName: DAILY_STATISTIC_NAME,
            Value: encodedValue,
          },
        ],
      };

      PlayFabClient.UpdatePlayerStatistics(request, (error, result) => {
        if (error || !result || result.code !== 200) {
          return resolve({ submitted: false, reason: "error", error });
        }

        markDailyScoreSubmitted(version, this.storage || undefined);
        resolve({ submitted: true });
      });
    });
  }

  /**
   * Updates the player's title display name.
   * PlayFab requires names between 3 and 25 characters.
   */
  public async updateDisplayName(name: string): Promise<string> {
    const trimmed = name.trim();
    if (trimmed.length < 3 || trimmed.length > 25) {
      throw new Error("Display name must be between 3 and 25 characters");
    }

    await this.login();

    return new Promise<string>((resolve, reject) => {
      PlayFabClient.UpdateUserTitleDisplayName({ DisplayName: trimmed }, (error, result) => {
        if (error || !result || result.code !== 200) {
          return reject(error || new Error("Failed to update display name"));
        }

        const newName = result.data.DisplayName || trimmed;
        this.currentDisplayName = newName;
        resolve(newName);
      });
    });
  }
}

// Global default singleton
export const playFabService = new PlayFabService();
