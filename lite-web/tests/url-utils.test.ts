import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { removeQueryParam } from "../src/utils/url";

describe("URL utilities", () => {
  let originalWindow: any;

  beforeEach(() => {
    originalWindow = (global as any).window;
    let currentHref = "https://marvelloussoft.github.io/liquidum/?id=test-steam-key&mode=daily";

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
        // Resolve relative or path URL if needed
        const resolved = new URL(newUrl, currentHref);
        currentHref = resolved.href;
      }),
    };

    (global as any).window = {
      location: mockLocation,
      history: mockHistory,
    };
  });

  afterEach(() => {
    (global as any).window = originalWindow;
  });

  it("removes id query parameter without affecting other parameters", () => {
    expect(window.location.search).toContain("id=test-steam-key");
    removeQueryParam("id");
    expect(window.location.search).toBe("?mode=daily");
    expect(window.location.href).toBe("https://marvelloussoft.github.io/liquidum/?mode=daily");
  });

  it("removes parameter completely when it is the only one", () => {
    window.location.href = "https://marvelloussoft.github.io/liquidum/?id=test-steam-key";
    removeQueryParam("id");
    expect(window.location.search).toBe("");
    expect(window.location.href).toBe("https://marvelloussoft.github.io/liquidum/");
  });

  it("does nothing if parameter does not exist", () => {
    window.location.href = "https://marvelloussoft.github.io/liquidum/?mode=daily";
    removeQueryParam("id");
    expect(window.location.search).toBe("?mode=daily");
  });
});
