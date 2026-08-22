import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen } from "@testing-library/react";
import { MemoryRouter, Routes, Route } from "react-router-dom";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import type { ReactNode } from "react";
import ExperimentDetailPage from "../../src/pages/ExperimentDetailPage";
import ExperimentTimelinePage from "../../src/pages/ExperimentTimelinePage";

// Neither page fetches anything here: rendering the page at a route with no
// :id param leaves `id` undefined, which disables the underlying queries
// (`enabled: !!id`) so they resolve with no data and no error — exactly the
// "query succeeded, nothing to show" case EmptyState exists for.
vi.mock("../../src/lib/api", () => ({
  api: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
  },
  getWebSocketUrl: () => "ws://localhost:4000/socket",
  ApiError: class ApiError extends Error {
    status: number;
    body: unknown;

    constructor(status: number, body: unknown, message: string) {
      super(message);
      this.status = status;
      this.body = body;
    }
  },
}));

function renderAt(path: string, element: ReactNode) {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });

  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={[path]}>
        <Routes>
          <Route path="/experiments/missing-id" element={element} />
        </Routes>
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

describe("ExperimentDetailPage — not found", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("renders EmptyState (not ErrorState) with a link back to the experiments list", () => {
    renderAt("/experiments/missing-id", <ExperimentDetailPage />);

    expect(screen.getByText("Experiment not found")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Back to experiments" })).toHaveAttribute(
      "href",
      "/experiments",
    );
    // ErrorState renders inside a red alert box; EmptyState doesn't.
    expect(document.querySelector(".bg-red-50")).not.toBeInTheDocument();
  });
});

describe("ExperimentTimelinePage — not found", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("renders EmptyState (not ErrorState) with a link back to the experiments list", () => {
    renderAt("/experiments/missing-id", <ExperimentTimelinePage />);

    expect(screen.getByText("Experiment not found")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Back to experiments" })).toHaveAttribute(
      "href",
      "/experiments",
    );
    expect(document.querySelector(".bg-red-50")).not.toBeInTheDocument();
  });
});
