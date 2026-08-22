import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import type { ReactNode } from "react";
import MetricDefinitionsPage from "../../src/pages/MetricDefinitionsPage";
import type { MetricDefinition } from "../../src/lib/types";

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
  describeApiError: (error: unknown) => (error instanceof Error ? error.message : "Unknown error"),
}));

import { api } from "../../src/lib/api";

function createWrapper() {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });

  return ({ children }: { children: ReactNode }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  );
}

const metric: MetricDefinition = {
  id: "m-1",
  key: "signup_rate",
  name: "Signup Rate",
  description: "Share of visitors who sign up.",
  metric_type: "ratio",
  definition: { numerator: "signup", denominator: "visit" },
};

describe("MetricDefinitionsPage — keyboard-operable rows", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(api.get).mockImplementation((url: string) => {
      if (url.startsWith("/api/v1/metric-definitions/")) {
        return Promise.resolve(metric);
      }
      return Promise.resolve({ data: [metric] });
    });
  });

  it("marks each row as a keyboard-focusable button naming the metric", async () => {
    render(<MetricDefinitionsPage />, { wrapper: createWrapper() });

    const row = await screen.findByRole("button", { name: "Edit metric Signup Rate" });
    expect(row.tagName).toBe("TR");
    expect(row).toHaveAttribute("tabindex", "0");
  });

  it("opens the edit panel when Enter is pressed on a focused row", async () => {
    render(<MetricDefinitionsPage />, { wrapper: createWrapper() });

    const row = await screen.findByRole("button", { name: "Edit metric Signup Rate" });
    row.focus();
    expect(document.activeElement).toBe(row);

    fireEvent.keyDown(row, { key: "Enter" });

    expect(await screen.findByRole("dialog", { name: "Edit metric definition" })).toBeInTheDocument();
    expect(await screen.findByRole("heading", { name: "Edit Metric" })).toBeInTheDocument();
  });

  it("opens the edit panel when Space is pressed on a focused row", async () => {
    render(<MetricDefinitionsPage />, { wrapper: createWrapper() });

    const row = await screen.findByRole("button", { name: "Edit metric Signup Rate" });
    row.focus();

    fireEvent.keyDown(row, { key: " " });

    expect(await screen.findByRole("dialog", { name: "Edit metric definition" })).toBeInTheDocument();
  });
});
