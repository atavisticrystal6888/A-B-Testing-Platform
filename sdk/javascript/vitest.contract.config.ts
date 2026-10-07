import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["test/contract/**/*.test.ts"],
    environment: "node",
    testTimeout: 15_000,
    // Contract tests share one tenant; run them in order, one at a time.
    fileParallelism: false,
    sequence: { concurrent: false },
  },
});
