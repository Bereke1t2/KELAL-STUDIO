import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// The portal is served entirely behind a login (PRD §4: Brand Kit config +
// admin), so there is no SEO or SSR requirement — a static SPA bundle keeps
// the deploy a single artifact.
export default defineConfig({
  plugins: [react()],
  server: {
    // The API is same-origin under /v1 in production; proxy it in dev so the
    // client never needs an absolute base URL or CORS in local development.
    proxy: {
      '/v1': {
        target: process.env.VITE_API_TARGET ?? 'http://localhost:8080',
        changeOrigin: true,
      },
    },
  },
});
