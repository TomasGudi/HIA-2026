import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// La URL del backend NUNCA se hardcodea: en desarrollo va por el proxy de Vite,
// en producción por el proxy de nginx (mismo origen, sin CORS).
const API_TARGET = process.env.VITE_API_TARGET || 'http://localhost:3000'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: API_TARGET,
        changeOrigin: true,
        rewrite: (p) => p.replace(/^\/api/, '/api'),
      },
    },
  },
  build: {
    outDir: 'dist',
    sourcemap: false,
  },
})
