import { defineConfig } from "@playwright/test";
import path from "node:path";
import { fileURLToPath } from "node:url";

// Resolve repo root so webServer commands run from there.
const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "..", "..");

export default defineConfig({
  testDir: "./tests",
  timeout: 60_000,
  expect: { timeout: 10_000 },
  fullyParallel: false,
  retries: 1,
  workers: 1,
  reporter: [["list"]],
  use: {
    baseURL: "http://localhost:5173",
    trace: "retain-on-failure",
    video: "retain-on-failure",
    screenshot: "only-on-failure",
  },
  webServer: [
    {
      command: "bundle exec rails s -p 3000",
      cwd: repoRoot,
      url: "http://localhost:3000/up",
      reuseExistingServer: true,
      timeout: 120_000,
      env: { RAILS_ENV: "development" },
    },
    {
      command: "bundle exec bin/jobs",
      cwd: repoRoot,
      url: "http://localhost:3000/up",
      reuseExistingServer: true,
      timeout: 60_000,
    },
    {
      command: "pnpm --dir frontend dev --port 5173",
      cwd: repoRoot,
      url: "http://localhost:5173",
      reuseExistingServer: true,
      timeout: 60_000,
    },
  ],
});
