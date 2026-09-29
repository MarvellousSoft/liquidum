/**
 * Utilities for URL manipulation and query parameter handling.
 */

/**
 * Removes a specific query parameter from the current browser URL
 * without triggering a page reload.
 */
export function removeQueryParam(paramKey: string): void {
  if (typeof window === "undefined" || !window.location) return;
  try {
    const url = new URL(window.location.href);
    if (url.searchParams.has(paramKey)) {
      url.searchParams.delete(paramKey);
      const cleanSearch = url.searchParams.toString();
      const newUrl = `${url.pathname}${cleanSearch ? `?${cleanSearch}` : ""}${url.hash}`;
      window.history.replaceState({}, "", newUrl);
    }
  } catch {
    // Ignore environments where URL or history is not fully supported
  }
}
