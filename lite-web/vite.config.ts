import preact from '@preact/preset-vite'
import tailwindcss from '@tailwindcss/vite'
import { defineConfig } from 'vite'
import { VitePWA } from 'vite-plugin-pwa'

// https://vite.dev/config/
export default defineConfig({
  base: './',
  plugins: [
    tailwindcss(),
    preact(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['favicon.svg', 'icons.svg', 'icons/*.png'],
      manifest: {
        name: 'Liquidum Lite',
        short_name: 'Liquidum',
        description: 'An aquarium-based logic puzzle game with daily challenges.',
        theme_color: '#237482',
        background_color: '#000924',
        display: 'standalone',
        orientation: 'portrait',
        icons: [
          {
            src: 'icons/boat.png',
            sizes: '192x192',
            type: 'image/png'
          },
          {
            src: 'icons/boat.png',
            sizes: '512x512',
            type: 'image/png'
          }
        ]
      }
    })
  ],
})
