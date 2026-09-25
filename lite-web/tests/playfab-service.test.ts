import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import {
  getDailyLeaderboardVersion,
  getDateStringForOffset,
  encodeDailyScore,
  decodeDailyScore,
  getOrCreateCustomId,
  isDailyScoreSubmitted,
  markDailyScoreSubmitted,
  extractDisplayNameFromProfile,
  extractAvatarUrlFromProfile,
  PlayFabService,
  PLAYFAB_TITLE_ID,
  DAILY_STATISTIC_NAME,
} from "../src/engine/PlayFabService";
import { getGeneratedName } from "../src/engine/NameGenerator";
import {
  decodeFlairFromInt,
  encodeFlairToInt,
  createFlair,
  FlairId,
} from "../src/engine/FlairManager";

// Helper in-memory storage for testing
function createMockStorage(): Storage {
  const store = new Map<string, string>();
  return {
    getItem: (key: string) => store.get(key) ?? null,
    setItem: (key: string, val: string) => {
      store.set(key, String(val));
    },
    removeItem: (key: string) => {
      store.delete(key);
    },
    clear: () => store.clear(),
    key: (index: number) => Array.from(store.keys())[index] ?? null,
    get length() {
      return store.size;
    },
  };
}

describe("PlayFabService - Formulas & Score Encoding", () => {
  it("calculates correct daily version matching production Godot logic", () => {
    // Base date: 2024-04-16 is Version 0
    expect(getDailyLeaderboardVersion("2024-04-16")).toBe(0);
    expect(getDailyLeaderboardVersion("2024-04-17")).toBe(1);

    // 2026-09-16 is Version 883
    expect(getDailyLeaderboardVersion("2026-09-16")).toBe(883);

    // Yesterday: 2026-09-15 is Version 882
    expect(getDailyLeaderboardVersion("2026-09-15")).toBe(882);

    // Date object parameter
    const d = new Date("2026-09-16T12:00:00Z");
    expect(getDailyLeaderboardVersion(d)).toBe(883);
  });

  it("calculates offset date strings correctly", () => {
    const today = getDateStringForOffset(0);
    expect(today).toMatch(/^\d{4}-\d{2}-\d{2}$/);

    const yesterday = getDateStringForOffset(-1);
    expect(yesterday).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    expect(today).not.toBe(yesterday);
  });

  it("encodes score into a negative integer prioritizing mistakes", () => {
    // 0 mistakes, 58 seconds -> -58
    expect(encodeDailyScore(58, 0)).toBe(-58);

    // 1 mistake, 45 seconds -> -100045
    expect(encodeDailyScore(45, 1)).toBe(-100045);

    // 2 mistakes, 120 seconds -> -200120
    expect(encodeDailyScore(120, 2)).toBe(-200120);

    // Clamps max time and mistakes
    expect(encodeDailyScore(999999, 5000)).toBe(-1 * (99999 + 1000 * 100000));
  });

  it("decodes score into seconds and mistakes accurately", () => {
    expect(decodeDailyScore(-58)).toEqual({ seconds: 58, mistakes: 0 });
    expect(decodeDailyScore(-100045)).toEqual({ seconds: 45, mistakes: 1 });
    expect(decodeDailyScore(-200120)).toEqual({ seconds: 120, mistakes: 2 });
    expect(decodeDailyScore(0)).toEqual({ seconds: 0, mistakes: 0 });
  });
});

describe("PlayFabService - Local Storage Tracking", () => {
  it("generates and persists custom ID in storage", () => {
    const storage = createMockStorage();
    const id1 = getOrCreateCustomId(storage);
    expect(id1).toBeTruthy();
    expect(storage.getItem("liquidum_custom_id")).toBe(id1);

    // Subsequent retrieval returns the same ID
    const id2 = getOrCreateCustomId(storage);
    expect(id2).toBe(id1);
  });

  it("tracks whether a daily score has been submitted", () => {
    const storage = createMockStorage();
    const version = 883;

    expect(isDailyScoreSubmitted(version, storage)).toBe(false);
    markDailyScoreSubmitted(version, storage);
    expect(isDailyScoreSubmitted(version, storage)).toBe(true);

    // Other versions remain unsubmitted
    expect(isDailyScoreSubmitted(882, storage)).toBe(false);
  });
});

describe("PlayFabService - Mocked API Workflows", () => {
  let mockStorage: Storage;
  let mockUserData: Record<string, { Value: string }> = {};
  let service: PlayFabService;
  let fetchSpy: any;

  beforeEach(() => {
    mockStorage = createMockStorage();
    mockUserData = {};
    service = new PlayFabService(mockStorage);

    // Safeguard: mock fetch completely so NO real network requests ever go out
    fetchSpy = vi.spyOn(globalThis, "fetch").mockImplementation(async (url: any, options: any) => {
      const urlStr = String(url);
      const body = JSON.parse(options?.body || "{}");

      if (urlStr.includes("/Client/LoginWithCustomID")) {
        const isSwitched = body.CustomId && body.CustomId.startsWith("KEY_");
        return new Response(
          JSON.stringify({
            code: 200,
            status: "OK",
            data: {
              PlayFabId: isSwitched ? `PF_${body.CustomId}` : "PLAYFAB_USER_123",
              SessionTicket: "MOCK_SESSION_TICKET_ABC",
              NewlyCreated: true,
              InfoResultPayload: {
                PlayerProfile: {
                  DisplayName: isSwitched ? `User_${body.CustomId}` : "AquaMaster",
                },
                UserData: mockUserData,
              },
            },
          }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        );
      }

      if (urlStr.includes("/Client/GetLeaderboard")) {
        if (body.StatisticName === "flair") {
          return new Response(
            JSON.stringify({
              code: 200,
              status: "OK",
              data: {
                Leaderboard: [
                  {
                    Position: 0,
                    PlayFabId: "PLAYER_TOP_1",
                    StatValue: 1, // Streak30 (id=1, extraFlairs=0)
                  },
                  {
                    Position: 1,
                    PlayFabId: "PLAYFAB_USER_123",
                    StatValue: 9999 + 2 * 1000000, // Dev with +2 extra flairs
                  },
                ],
              },
            }),
            { status: 200, headers: { "Content-Type": "application/json" } }
          );
        }

        return new Response(
          JSON.stringify({
            code: 200,
            status: "OK",
            data: {
              Leaderboard: [
                {
                  Position: 0,
                  PlayFabId: "PLAYER_TOP_1",
                  DisplayName: "CoralReef",
                  Profile: {
                    DisplayName: "CoralReef",
                    AvatarUrl: "https://example.com/avatar1.png",
                  },
                  StatValue: -55, // 0 mistakes, 55s
                },
                {
                  Position: 1,
                  PlayFabId: "PLAYFAB_USER_123", // Current user
                  DisplayName: "AquaMaster",
                  Profile: {
                    DisplayName: "AquaMaster",
                    AvatarUrl: null,
                  },
                  StatValue: -100045, // 1 mistake, 45s
                },
                {
                  Position: 2,
                  PlayFabId: "PLAYER_3",
                  DisplayName: "", // Anonymous fallback to generated name
                  Profile: {},
                  StatValue: -200110, // 2 mistakes, 110s
                },
              ],
            },
          }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        );
      }

      if (urlStr.includes("/Client/UpdatePlayerStatistics")) {
        return new Response(
          JSON.stringify({
            code: 200,
            status: "OK",
            data: {},
          }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        );
      }

      if (urlStr.includes("/Client/UpdateUserTitleDisplayName")) {
        return new Response(
          JSON.stringify({
            code: 200,
            status: "OK",
            data: {
              DisplayName: body.DisplayName,
            },
          }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        );
      }

      if (urlStr.includes("/Client/UpdateAvatarUrl")) {
        return new Response(
          JSON.stringify({
            code: 200,
            status: "OK",
            data: {},
          }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        );
      }

      if (urlStr.includes("/Client/GetUserData")) {
        return new Response(
          JSON.stringify({
            code: 200,
            status: "OK",
            data: {
              Data: mockUserData,
            },
          }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        );
      }

      if (urlStr.includes("/Client/UpdateUserData")) {
        if (body.Data) {
          for (const [k, v] of Object.entries(body.Data)) {
            mockUserData[k] = { Value: String(v) };
          }
        }
        return new Response(
          JSON.stringify({
            code: 200,
            status: "OK",
            data: { DataVersion: 1 },
          }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        );
      }

      throw new Error(`Unhandled PlayFab endpoint called in test: ${urlStr}`);
    });
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("logs in anonymously and caches credentials", async () => {
    const result = await service.login();

    expect(result.playFabId).toBe("PLAYFAB_USER_123");
    expect(result.displayName).toBe("AquaMaster");
    expect(result.newlyCreated).toBe(true);
    expect(service.isLoggedIn()).toBe(true);

    // Check fetch was called with TitleId and CustomId
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    const [calledUrl, calledOptions] = fetchSpy.mock.calls[0];
    expect(calledUrl).toContain(`https://${PLAYFAB_TITLE_ID}.playfabapi.com/Client/LoginWithCustomID`);
    const sentBody = JSON.parse(calledOptions.body);
    expect(sentBody.TitleId).toBe(PLAYFAB_TITLE_ID);
    expect(sentBody.CustomId).toBeTruthy();

    // Second call should return cached login without another network call
    const cached = await service.login();
    expect(cached.playFabId).toBe("PLAYFAB_USER_123");
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  it("fetches daily leaderboard with decoded entries and highlights current player", async () => {
    const entries = await service.getLeaderboard(883);

    expect(entries).toHaveLength(3);

    // Rank 1
    expect(entries[0]).toEqual({
      position: 1,
      playFabId: "PLAYER_TOP_1",
      displayName: "CoralReef",
      avatarUrl: "https://example.com/avatar1.png",
      flair: {
        id: 1,
        extraFlairs: 0,
        text: "30✓",
        color: "#ff4500",
        description: "Got a 30 daily streak",
      },
      seconds: 55,
      mistakes: 0,
      rawScore: -55,
      isCurrentUser: false,
    });

    // Rank 2 - Current User
    expect(entries[1]).toEqual({
      position: 2,
      playFabId: "PLAYFAB_USER_123",
      displayName: "AquaMaster",
      avatarUrl: null,
      flair: {
        id: 9999,
        extraFlairs: 2,
        text: "dev",
        color: "#ef4444",
        description: "Developer of Liquidum",
      },
      seconds: 45,
      mistakes: 1,
      rawScore: -100045,
      isCurrentUser: true,
    });

    // Rank 3 - Fallback name
    expect(entries[2]).toEqual({
      position: 3,
      playFabId: "PLAYER_3",
      displayName: getGeneratedName("PLAYER_3"),
      avatarUrl: null,
      flair: null,
      seconds: 110,
      mistakes: 2,
      rawScore: -200110,
      isCurrentUser: false,
    });

    // Verify GetLeaderboard request payload
    const lbCall = fetchSpy.mock.calls.find((c: any) => c[0].includes("/Client/GetLeaderboard"));
    expect(lbCall).toBeTruthy();
    const req = JSON.parse(lbCall[1].body);
    expect(req.StatisticName).toBe(DAILY_STATISTIC_NAME);
    expect(req.Version).toBe(883);
  });

  it("submits score only on the very first completion and skips subsequent solves", async () => {
    const version = getDailyLeaderboardVersion();

    // First attempt: should submit
    const firstResult = await service.submitDailyScore(45, 1, version);
    expect(firstResult.submitted).toBe(true);

    const updateCall = fetchSpy.mock.calls.find((c: any) =>
      c[0].includes("/Client/UpdatePlayerStatistics")
    );
    expect(updateCall).toBeTruthy();
    const req = JSON.parse(updateCall[1].body);
    expect(req.Statistics[0].StatisticName).toBe(DAILY_STATISTIC_NAME);
    expect(req.Statistics[0].Value).toBe(-100045);

    // Storage is now marked
    expect(isDailyScoreSubmitted(version, mockStorage)).toBe(true);

    // Second attempt on the same day: MUST be skipped and not call API
    const initialCalls = fetchSpy.mock.calls.length;
    const secondResult = await service.submitDailyScore(30, 0, version);

    expect(secondResult.submitted).toBe(false);
    expect(secondResult.reason).toBe("already_submitted");
    expect(fetchSpy.mock.calls.length).toBe(initialCalls); // No new network call!
  });

  it("skips score submission for older past daily levels", async () => {
    const olderDate = "2024-01-07"; // In the past
    const result = await service.submitDailyScore(45, 0, olderDate);
    expect(result.submitted).toBe(false);
    expect(result.reason).toBe("older_level");
  });

  it("validates and updates display name", async () => {
    // Rejects too short name without network request
    await expect(service.updateDisplayName("ab")).rejects.toThrow(
      "Display name must be between 3 and 25 characters"
    );

    // Rejects too long name
    await expect(service.updateDisplayName("A".repeat(26))).rejects.toThrow(
      "Display name must be between 3 and 25 characters"
    );

    // Valid update
    const updated = await service.updateDisplayName("NewAquaHero");
    expect(updated).toBe("NewAquaHero");
    expect(service.getDisplayName()).toBe("NewAquaHero");

    const updateCall = fetchSpy.mock.calls.find((c: any) =>
      c[0].includes("/Client/UpdateUserTitleDisplayName")
    );
    expect(updateCall).toBeTruthy();
    const req = JSON.parse(updateCall[1].body);
    expect(req.DisplayName).toBe("NewAquaHero");
  });

  it("handles PlayFab API failure gracefully", async () => {
    // Override fetch to simulate PlayFab error
    fetchSpy.mockImplementationOnce(async () => {
      return new Response(
        JSON.stringify({
          code: 400,
          status: "BadRequest",
          error: "NameNotAvailable",
          errorMessage: "The display name is already taken",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    });

    const failingService = new PlayFabService(createMockStorage());
    await expect(failingService.login()).rejects.toBeTruthy();
  });

  it("updates and removes player avatar URL", async () => {
    await service.login();

    // Set avatar
    const newAvatar = await service.updateAvatarUrl("https://example.com/fish.png");
    expect(newAvatar).toBe("https://example.com/fish.png");
    expect(service.getAvatarUrl()).toBe("https://example.com/fish.png");

    const updateCall = fetchSpy.mock.calls.find((c: any) =>
      c[0].includes("/Client/UpdateAvatarUrl")
    );
    expect(updateCall).toBeTruthy();
    const req = JSON.parse(updateCall[1].body);
    expect(req.ImageUrl).toBe("https://example.com/fish.png");

    // Remove avatar (empty string)
    const cleared = await service.updateAvatarUrl("   ");
    expect(cleared).toBeNull();
    expect(service.getAvatarUrl()).toBeNull();
  });

  it("retrieves current customId recovery key", () => {
    const key = service.getCustomId();
    expect(key).toBeTruthy();
    expect(mockStorage.getItem("liquidum_custom_id")).toBe(key);
  });

  it("notifies profile change listeners when name, avatar, or account changes", async () => {
    const events: any[] = [];
    const unsubscribe = service.onProfileChange((e) => {
      events.push(e);
    });

    await service.login();
    expect(events.length).toBeGreaterThanOrEqual(1);
    expect(events[events.length - 1].displayName).toBe("AquaMaster");

    await service.updateDisplayName("AquaCaptain");
    expect(events[events.length - 1].displayName).toBe("AquaCaptain");

    await service.updateAvatarUrl("https://example.com/pic.png");
    expect(events[events.length - 1].avatarUrl).toBe("https://example.com/pic.png");

    unsubscribe();
    await service.updateDisplayName("AquaAdmiral");
    // Should not receive further events after unsubscribe
    expect(events[events.length - 1].displayName).toBe("AquaCaptain");
  });

  it("switches account using a recovery key and reloads identity", async () => {
    await service.login();
    expect(service.getPlayFabId()).toBe("PLAYFAB_USER_123");

    const newResult = await service.switchAccount("KEY_RESTORED_999");
    expect(newResult.playFabId).toBe("PF_KEY_RESTORED_999");
    expect(service.getPlayFabId()).toBe("PF_KEY_RESTORED_999");
    expect(service.getDisplayName()).toBe("User_KEY_RESTORED_999");
    expect(mockStorage.getItem("liquidum_custom_id")).toBe("KEY_RESTORED_999");
  });

  describe("PlayFabService - Cloud Streak Synchronization", () => {
    it("retrieves streaks from UserData during login and updates local storage", async () => {
      const today = "2026-09-24";
      mockUserData["streaks"] = {
        Value: JSON.stringify({
          daily: { cur: 5, best: 10, last: today },
          weekly: { cur: 3, best: 6, last: "2026-09-21" },
        }),
      };

      let listenerNotifiedStreak: any = null;
      service.onStreakChange((streak) => {
        listenerNotifiedStreak = streak;
      });

      await service.login();

      expect(listenerNotifiedStreak).toEqual({
        currentStreak: 5,
        bestStreak: 10,
        lastCompletedDay: today,
      });

      const cached = service.getCachedCloudStreaks();
      expect(cached?.daily).toEqual({ cur: 5, best: 10, last: today });
      expect(cached?.weekly).toEqual({ cur: 3, best: 6, last: "2026-09-21" });
    });

    it("updates daily streak while preserving weekly marathon streak", async () => {
      mockUserData["streaks"] = {
        Value: JSON.stringify({
          daily: { cur: 2, best: 5, last: "2026-09-23" },
          weekly: { cur: 4, best: 7, last: "2026-09-21" },
        }),
      };

      await service.login();

      const ok = await service.updateDailyStreak(
        {
          currentStreak: 3,
          bestStreak: 5,
          lastCompletedDay: "2026-09-24",
        },
        "2026-09-24"
      );

      expect(ok).toBe(true);

      const parsedCloud = JSON.parse(mockUserData["streaks"].Value);
      expect(parsedCloud.daily).toEqual({ cur: 3, best: 5, last: "2026-09-24" });
      // Weekly streak must remain untouched!
      expect(parsedCloud.weekly).toEqual({ cur: 4, best: 7, last: "2026-09-21" });
    });
  });
});

describe("PlayFabService - Profile Data Extraction (Godot Parity)", () => {
  it("extracts display name following priority: DisplayName -> LinkedAccounts -> Generated Name", () => {
    // 1. Direct DisplayName
    expect(
      extractDisplayNameFromProfile(
        { DisplayName: "OceanKing" },
        "USER_1"
      )
    ).toBe("OceanKing");

    // 2. LinkedAccounts Username if DisplayName is empty or missing
    expect(
      extractDisplayNameFromProfile(
        {
          DisplayName: "",
          LinkedAccounts: [{ Platform: "Steam", Username: "SteamSailor" }],
        },
        "USER_2"
      )
    ).toBe("SteamSailor");

    // 3. Fallback to top-level raw name if provided
    expect(
      extractDisplayNameFromProfile(
        null,
        "USER_3",
        "DirectRawName"
      )
    ).toBe("DirectRawName");

    // 4. Deterministic NameGenerator fallback if no name or account found
    const generated = extractDisplayNameFromProfile(null, "USER_4");
    expect(generated).toBe(getGeneratedName("USER_4"));
    expect(generated.split(" ")).toHaveLength(2); // "<Adjective> <Animal>"
  });

  it("extracts avatarUrl from profile if present", () => {
    expect(
      extractAvatarUrlFromProfile({ AvatarUrl: "https://cdn.example.com/avatar.png" })
    ).toBe("https://cdn.example.com/avatar.png");

    expect(extractAvatarUrlFromProfile({ AvatarUrl: "" })).toBeNull();
    expect(extractAvatarUrlFromProfile(null)).toBeNull();
  });
});

describe("FlairManager - Flair Decoding & Ported Definitions", () => {
  it("encodes and decodes flair integers accurately", () => {
    expect(decodeFlairFromInt(-1)).toBeNull();
    expect(decodeFlairFromInt(undefined as any)).toBeNull();

    // Streak30 with 0 extra flairs
    expect(decodeFlairFromInt(1)).toEqual({ id: 1, extraFlairs: 0 });
    expect(encodeFlairToInt(1, 0)).toBe(1);

    // Dev with 2 extra flairs: 2 * 1,000,000 + 9999 = 2,009,999
    expect(decodeFlairFromInt(2009999)).toEqual({ id: 9999, extraFlairs: 2 });
    expect(encodeFlairToInt(9999, 2)).toBe(2009999);
  });

  it("creates standard flairs with correct metadata", () => {
    const streak = createFlair(FlairId.Streak30, 0);
    expect(streak).toEqual({
      id: 1,
      extraFlairs: 0,
      text: "30✓",
      color: "#ff4500",
      description: "Got a 30 daily streak",
    });

    const dev = createFlair(FlairId.Dev, 3);
    expect(dev).toEqual({
      id: 9999,
      extraFlairs: 3,
      text: "dev",
      color: "#ef4444",
      description: "Developer of Liquidum",
    });

    const dlc = createFlair(FlairId.Dlc, 0);
    expect(dlc?.text).toBe("❤");

    const won = createFlair(FlairId.MainCampaign, 0);
    expect(won?.text).toBe("won");
  });

  it("creates monthly pro flairs with deterministic color and formatted date", () => {
    // ProStart (10000) corresponds to February 2024
    const feb2024 = createFlair(FlairId.ProStart, 1);
    expect(feb2024?.text).toBe("pro");
    expect(feb2024?.extraFlairs).toBe(1);
    expect(feb2024?.description).toContain("February 2024");
    expect(feb2024?.color).toMatch(/^#[0-9a-f]{6}$/i);

    // March 2024 (10001)
    const mar2024 = createFlair(10001, 0);
    expect(mar2024?.description).toContain("March 2024");
  });

  it("creates extra island flairs", () => {
    const island1 = createFlair(FlairId.ExtraIslandStart + 1, 0);
    expect(island1?.text).toBe("🤏");
    expect(island1?.description).toBe("Completed island 1");

    const island3 = createFlair(FlairId.ExtraIslandStart + 3, 0);
    expect(island3?.text).toBe("👄");
    expect(island3?.color).toBe("#fe2d86");
  });
});


