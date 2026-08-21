import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import type { ReactNode } from "react";
import ExperimentListPage from "../../src/pages/ExperimentListPage";

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
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>{children}</MemoryRouter>
    </QueryClientProvider>
  );
}

describe("ExperimentListPage — Time to significance column", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("renders the compact projection string for each row, and a dash when absent", async () => {
    vi.mocked(api.get).mockResolvedValue({
      data: [
        {
          id: "exp-estimate",
          key: "exp-estimate",
          name: "Estimate Experiment",
          status: "running",
          variant_count: 2,
          inserted_at: "2026-08-01T00:00:00Z",
          days_to_significance: { status: "estimate", days_remaining: 16 },
        },
        {
          id: "exp-never",
          key: "exp-never",
          name: "May Never Experiment",
          status: "running",
          variant_count: 2,
          inserted_at: "2026-08-01T00:00:00Z",
          days_to_significance: { status: "may_never", days_remaining: null },
        },
        {
          id: "exp-none",
          key: "exp-none",
          name: "No Projection Experiment",
          status: "draft",
          variant_count: 2,
          inserted_at: "2026-08-01T00:00:00Z",
          days_to_significance: null,
        },
      ],
      meta: { page: 1, page_size: 20, total: 3, total_pages: 1 },
    });

    render(<ExperimentListPage />, { wrapper: createWrapper() });

    expect(await screen.findByText("Estimate Experiment")).toBeInTheDocument();
    expect(screen.getByText("~16d")).toBeInTheDocument();
    expect(screen.getByText("may never")).toBeInTheDocument();
    expect(screen.getByText("—")).toBeInTheDocument();
  });
});
