import { render } from 'preact'
import './index.css'
import { App } from './app.tsx'

if (typeof window !== 'undefined') {
  window.addEventListener('vite:preloadError', () => {
    const lastReload = sessionStorage.getItem('last_preload_reload');
    const now = Date.now();
    if (!lastReload || now - Number(lastReload) > 10000) {
      sessionStorage.setItem('last_preload_reload', String(now));
      console.warn('Vite dynamic import chunk failed to load (deployment update detected). Reloading page...');
      window.location.reload();
    }
  });
}

render(<App />, document.getElementById('app')!)

