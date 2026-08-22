import "@testing-library/jest-dom";

// jsdom has no ResizeObserver; recharts' <ResponsiveContainer> needs one to
// mount at all (it throws in the mount effect otherwise). A no-op stub is
// enough for tests — they don't depend on actual resize callbacks firing.
if (typeof globalThis.ResizeObserver === "undefined") {
  class ResizeObserverStub {
    observe() {}
    unobserve() {}
    disconnect() {}
  }

  globalThis.ResizeObserver = ResizeObserverStub as unknown as typeof ResizeObserver;
}
