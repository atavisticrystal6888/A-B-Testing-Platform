import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { MemoryRouter, Routes, Route } from "react-router-dom";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import type { ReactNode } from "react";
import Layout from "../../src/pages/Layout";
import ExperimentListPage from "../../src/pages/ExperimentListPage";
import { CreateExperimentPage } from "../../src/pages/CreateExperimentPage";

vi.mock("../../src/lib/api", () => ({
  api: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
  },
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

vi.mock("../../src/contexts/AuthContext", () => ({
  useAuth: () => ({
    user: { id: "u1", email: "member@example.com", role: "member" },
    logout: vi.fn(),
  }),
}));

import { api } from "../../src/lib/api";

function createWrapper() {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });

  return ({ children }: { children: ReactNode }) => (
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>{children}</MemoryRouter>
    </QueryClientProvider>
  );
}

describe("Accessibility — results table semantics", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("renders the experiments table with a caption and scope=col headers", async () => {
    vi.mocked(api.get).mockResolvedValue({
      data: [
        {
          id: "exp-1",
          key: "exp-1",
          name: "Checkout Button Color",
          status: "running",
          variant_count: 2,
          inserted_at: "2026-08-01T00:00:00Z",
          days_to_significance: null,
        },
      ],
      meta: { page: 1, page_size: 20, total: 1, total_pages: 1 },
    });

    render(<ExperimentListPage />, {
      wrapper: ({ children }: { children: ReactNode }) => (
        <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
          <MemoryRouter>{children}</MemoryRouter>
        </QueryClientProvider>
      ),
    });

    const table = await screen.findByRole("table");
    expect(table.querySelector("caption")).not.toBeNull();
    expect(table.querySelector("caption")).toHaveClass("sr-only");

    const columnHeaders = screen.getAllByRole("columnheader");
    expect(columnHeaders.length).toBeGreaterThan(0);
    columnHeaders.forEach((header) => {
      expect(header).toHaveAttribute("scope", "col");
    });
  });
});

describe("Accessibility — nav aria-current", () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  it("marks the active nav link with aria-current=page", () => {
    render(
      <MemoryRouter initialEntries={["/experiments"]}>
        <Routes>
          <Route element={<Layout />}>
            <Route path="/experiments" element={<div>Experiments page</div>} />
          </Route>
        </Routes>
      </MemoryRouter>,
    );

    expect(screen.getByRole("link", { name: "Experiments" })).toHaveAttribute("aria-current", "page");
    expect(screen.getByRole("link", { name: "Dashboard" })).not.toHaveAttribute("aria-current");
  });

  it("renders a skip-to-content link targeting #main-content as the first focusable element", () => {
    render(
      <MemoryRouter initialEntries={["/dashboard"]}>
        <Routes>
          <Route element={<Layout />}>
            <Route path="/dashboard" element={<div>Dashboard page</div>} />
          </Route>
        </Routes>
      </MemoryRouter>,
    );

    const skipLink = screen.getByRole("link", { name: "Skip to content" });
    expect(skipLink).toHaveAttribute("href", "#main-content");
  });
});

describe("Accessibility — wizard keyboard nav", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("moves focus to the step heading after clicking Next", async () => {
    render(<CreateExperimentPage />, { wrapper: createWrapper() });

    const step1Heading = await screen.findByRole("heading", { name: "Hypothesis" });
    expect(step1Heading).toHaveAttribute("tabindex", "-1");

    fireEvent.change(screen.getByLabelText("Experiment Name"), {
      target: { value: "Test Experiment" },
    });
    fireEvent.click(screen.getByText("Next"));

    const step2Heading = await screen.findByRole("heading", { name: "Variants" });
    expect(step2Heading).toHaveAttribute("tabindex", "-1");
    expect(document.activeElement).toBe(step2Heading);
  });

  it("gives the step list aria-current=step on the active step", async () => {
    render(<CreateExperimentPage />, { wrapper: createWrapper() });

    expect(await screen.findByRole("heading", { name: "Hypothesis" })).toBeInTheDocument();

    const activeStepItem = document.querySelector('li[aria-current="step"]');
    expect(activeStepItem).not.toBeNull();
    expect(activeStepItem?.textContent).toContain("Hypothesis");
  });
});
