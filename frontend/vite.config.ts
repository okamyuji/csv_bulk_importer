import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwind from "@tailwindcss/vite";

// Vite dev server. Proxies /api and /cable to the Rails app on :3000
// so the SPA can run same-origin relative URLs.
export default defineConfig({
  plugins: [react(), tailwind()],
  server: {
    port: 5173,
    proxy: {
      "/api": "http://localhost:3000",
      "/cable": { target: "ws://localhost:3000", ws: true },
    },
  },
});
