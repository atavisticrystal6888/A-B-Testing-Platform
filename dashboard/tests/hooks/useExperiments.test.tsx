import { describe, it, expect, vi, beforeEach } from "vitest";
import { renderHook, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import {
  useExperiments,
  useExperiment,
  normalizeExperimentListResponse,
} from "../../src/hooks/useExperiments";
import type { ReactNode } from "react";

// Mock API
vi.mock("../../src/lib/api", () => ({
  api: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
  },
}));

import { api } from "../../src/lib/api";

function createWrapper() {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return ({ children }: { children: ReactNode }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  );
}

describe("useExperiments", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("fetches experiments list", async () => {
    const mockData = {
      data: [
        { id: "1", name: "Test", key: "test", status: "draft", variants: [] },
      ],
      meta: { page: 1, total: 1, total_pages: 1 },
    };

    vi.mocked(api.get).mockResolvedValue(mockData);

    const { result } = renderHook(() => useExperiments(), {
      wrapper: createWrapper(),
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data?.data).toHaveLength(1);
  });

  it("normalizes legacy meta.total_count to meta.total", () => {
    const normalized = normalizeExperimentListResponse({
      data: [],
      meta: {
        page: 1,
        page_size: 20,
        total_count: 7,
        total_pages: 1,
      },
    });

    expect(normalized.meta.total).toBe(7);
  });
});

describe("useExperiment", () => {
  it("fetches single experiment", async () => {
    const mockData = {
      data: { id: "1", name: "Test", key: "test", status: "draft", variants: [] },
    };

    vi.mocked(api.get).mockResolvedValue(mockData);

    const { result } = renderHook(() => useExperiment("1"), {
      wrapper: createWrapper(),
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data?.data.name).toBe("Test");
  });
});
