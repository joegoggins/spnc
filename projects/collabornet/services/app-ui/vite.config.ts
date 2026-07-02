import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    // Dev-only: proxy /api -> local app-api (FastAPI/uvicorn default :8000),
    // stripping the /api prefix so /api/sites -> /sites. The dev server does
    // NOT run in the production container; nginx does the equivalent
    // proxy_pass there (see the app-ui image's nginx.conf).
    proxy: {
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, ''),
      },
    },
  },
})
