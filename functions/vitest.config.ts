import {defineConfig} from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    globals: true,
    include: ["tests/**/*.test.ts"],
    testTimeout: 20000,
    typecheck: {
      tsconfig: "./tsconfig.vitest.json",
    },
  },
});