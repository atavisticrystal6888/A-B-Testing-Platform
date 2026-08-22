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
        {
          id: "exp-paused-stale",
          key: "exp-paused-stale",
          name: "Paused Stale ETA Experiment",
          status: "paused",
          variant_count: 2,
          inserted_at: "2026-08-01T00:00:00Z",
          // Non-null projection left over from before the pause — must not
          // be rendered as a live ETA once the experiment isn't running.
          days_to_significance: { status: "estimate", days_remaining: 3 },
        },
      ],
      meta: { page: 1, page_size: 20, total: 4, total_pages: 1 },
    });

    render(<ExperimentListPage />, { wrapper: createWrapper() });

    expect(await screen.findByText("Estimate Experiment")).toBeInTheDocument();
    expect(screen.getByText("~16d")).toBeInTheDocument();
    expect(screen.getByText("may never")).toBeInTheDocument();
    expect(screen.queryByText("~3d")).not.toBeInTheDocument();

    // Two rows should each show a dash: the draft one (no projection at
    // all) and the paused one (stale non-null projection, suppressed
    // because the experiment isn't running).
    expect(screen.getAllByText("—")).toHaveLength(2);
  });
});

describe("ExperimentListPage — numeric column alignment", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("right-aligns the Variants and Time to significance columns, but not Created", async () => {
    vi.mocked(api.get).mockResolvedValue({
      data: [
        {
          id: "exp-1",
          key: "exp-1",
          name: "Checkout Button Color",
          status: "running",
          variant_count: 2,
          inserted_at: "2026-08-01T00:00:00Z",
          days_to_significance: { status: "estimate", days_remaining: 16 },
        },
      ],
      meta: { page: 1, page_size: 20, total: 1, total_pages: 1 },
    });

    render(<ExperimentListPage />, { wrapper: createWrapper() });

    await screen.findByText("Checkout Button Color");

    const variantsHeader = screen.getByRole("columnheader", { name: "Variants" });
    const createdHeader = screen.getByRole("columnheader", { name: "Created" });
    const etaHeader = screen.getByRole("columnheader", { name: "Time to significance" });

    expect(variantsHeader).toHaveClass("text-right");
    expect(etaHeader).toHaveClass("text-right");
    expect(createdHeader).not.toHaveClass("text-right");

    const variantsCell = screen.getByText("2 variants");
    const etaCell = screen.getByText("~16d");
    const createdCell = screen.getByText(new Date("2026-08-01T00:00:00Z").toLocaleDateString());

    expect(variantsCell).toHaveClass("text-right");
    expect(etaCell).toHaveClass("text-right");
    expect(createdCell).not.toHaveClass("text-right");
  });
});
