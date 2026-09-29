import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { getOrCreateCustomId } from "../src/engine/PlayFabService";
import { removeQueryParam } from "../src/utils/url";

describe("Account synchronization from URL query parameter (?id=...)", () => {
  let mockStorage: Map<string, string>;
  let originalWindow: any;
  let currentHref: string;

  beforeEach(() => {
    mockStorage = new Map<string, string>();
    originalWindow = (global as any).window;
    currentHref = "https://marvelloussoft.github.io/liquidum/?id=steam-key-12345";

    const mockLocation = {
      get href() {
        return currentHref;
      },
      set href(val: string) {
        currentHref = val;
      },
      get search() {
        const url = new URL(currentHref);
        return url.search;
      },
      get pathname() {
        const url = new URL(currentHref);
        return url.pathname;
      },
      get hash() {
        const url = new URL(currentHref);
        return url.hash;
      },
    };

    const mockHistory = {
      replaceState: vi.fn((_state: any, _title: string, newUrl: string) => {
        const resolved = new URL(newUrl, currentHref);
        currentHref = resolved.href;
      }),
    };

    const storageAdapter: Storage = {
      getItem: (key: string) => mockStorage.get(key) ?? null,
      setItem: (key: string, val: string) => {
        mockStorage.set(key, String(val));
      },
      removeItem: (key: string) => {
        mockStorage.delete(key);
      },
      clear: () => mockStorage.clear(),
      key: (i: number) => Array.from(mockStorage.keys())[i] ?? null,
      get length() {
        return mockStorage.size;
      },
    };

    (global as any).window = {
      location: mockLocation,
      history: mockHistory,
    };
    (global as any).localStorage = storageAdapter;
  });

  afterEach(() => {
    (global as any).window = originalWindow;
    delete (global as any).localStorage;
  });

  it("first time visitor: adopts received id without prompting and cleans URL", () => {
    const params = new URLSearchParams(window.location.search);
    const incomingId = params.get("id");
    const existingId = localStorage.getItem("liquidum_custom_id");
    const isFirstTime = existingId === null;

    expect(isFirstTime).toBe(true);
    expect(incomingId).toBe("steam-key-12345");

    if (incomingId && isFirstTime) {
      localStorage.setItem("liquidum_custom_id", incomingId);
      removeQueryParam("id");
    }

    expect(localStorage.getItem("liquidum_custom_id")).toBe("steam-key-12345");
    expect(window.location.search).toBe("");
  });

  it("returning visitor with same ID: ignores and cleans URL without prompting", () => {
    localStorage.setItem("liquidum_custom_id", "steam-key-12345");

    const params = new URLSearchParams(window.location.search);
    const incomingId = params.get("id");
    const existingId = localStorage.getItem("liquidum_custom_id");
    const isFirstTime = existingId === null;

    expect(isFirstTime).toBe(false);
    expect(existingId).toBe(incomingId);

    let promptShown = false;
    if (incomingId) {
      if (isFirstTime) {
        localStorage.setItem("liquidum_custom_id", incomingId);
        removeQueryParam("id");
      } else if (existingId === incomingId) {
        removeQueryParam("id");
      } else {
        promptShown = true;
      }
    }

    expect(promptShown).toBe(false);
    expect(localStorage.getItem("liquidum_custom_id")).toBe("steam-key-12345");
    expect(window.location.search).toBe("");
  });

  it("returning visitor with different ID: prompts user to confirm switch", () => {
    localStorage.setItem("liquidum_custom_id", "old-browser-key");

    const params = new URLSearchParams(window.location.search);
    const incomingId = params.get("id");
    const existingId = localStorage.getItem("liquidum_custom_id");
    const isFirstTime = existingId === null;

    expect(isFirstTime).toBe(false);
    expect(existingId).not.toBe(incomingId);

    let promptTargetId: string | null = null;
    if (incomingId) {
      if (isFirstTime) {
        localStorage.setItem("liquidum_custom_id", incomingId);
        removeQueryParam("id");
      } else if (existingId === incomingId) {
        removeQueryParam("id");
      } else {
        promptTargetId = incomingId;
      }
    }

    expect(promptTargetId).toBe("steam-key-12345");
    // URL param is kept until modal action (confirm or cancel)
    expect(window.location.search).toContain("id=steam-key-12345");
  });
});
