/**
 * Utility to resolve asset URLs correctly across base paths (e.g. GitHub Pages subpaths).
 * Always guarantees relative asset resolution (e.g. ./icons/...) so assets never 404
 * on subpath deployments.
 */
export function assetUrl(path: string): string {
  let base = import.meta.env.BASE_URL || './';
  if (base === '/') {
    base = './';
  }
  const cleanPath = path.startsWith('/') ? path.slice(1) : path;
  const cleanBase = base.endsWith('/') ? base : `${base}/`;
  return `${cleanBase}${cleanPath}`;
}

export function iconUrl(name: string): string {
  return assetUrl(`icons/${name}`);
}
