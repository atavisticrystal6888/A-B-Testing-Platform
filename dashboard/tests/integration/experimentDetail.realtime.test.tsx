import { StrictMode, type ReactNode } from "react";
import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { AuthProvider } from "../../src/contexts/AuthContext";
import { WebSocketProvider } from "../../src/contexts/WebSocketContext";
import ExperimentDetailPage from "../../src/pages/ExperimentDetailPage";

const socketSpies = vi.hoisted(() => ({
  construct: vi.fn(),
  connect: vi.fn(),
  disconnect: vi.fn(),
  channel: vi.fn(),
}));

vi.mock("phoenix", () => {
  class MockJoin {
    receive(status: string, callback?: (payload: unknown) => void) {
      if (status === "ok") {
        callback?.({});
      }

      return this;
    }
  }

  class MockChannel {
    topic: string;

    constructor(topic: string) {
      this.topic = topic;
    }

    on = vi.fn();
    join = vi.fn(() => new MockJoin());
    leave = vi.fn();
  }

  class MockSocket {
    private connected = false;
    private openCallbacks: Array<() => void> = [];
    private closeCallbacks: Array<() => void> = [];

    constructor(url: string, options: unknown) {
      socketSpies.construct(url, options);
    }

    isConnected() {
      return this.connected;
    }

    connect() {
      this.connected = true;
      socketSpies.connect();
      this.openCallbacks.forEach((callback) => callback());
    }

    disconnect() {
      this.connected = false;
      socketSpies.disconnect();
      this.closeCallbacks.forEach((callback) => callback());
    }

    onOpen(callback: () => void) {
      this.openCallbacks.push(callback);
    }

    onClose(callback: () => void) {
      this.closeCallbacks.push(callback);
    }

    channel(topic: string) {
      const channel = new MockChannel(topic);
      socketSpies.channel(topic);
      return channel;
    }
  }

  return { Socket: MockSocket };
});

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
      this.name = "ApiError";
      this.status = status;
      this.body = body;
    }
  },
}));

vi.mock("../../src/components/charts/ConfidenceIntervalChart", () => ({
  default: () => <div>Confidence Interval Chart</div>,
}));

vi.mock("../../src/components/charts/ConversionOverTimeChart", () => ({
  default: () => <div>Conversion Rate Over Time</div>,
}));

import { api } from "../../src/lib/api";

function createWrapper(initialPath = "/experiments/exp-1") {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
      },
    },
  });

  return ({ children }: { children: ReactNode }) => (
    <StrictMode>
      <QueryClientProvider client={queryClient}>
        <AuthProvider>
          <WebSocketProvider>
            <MemoryRouter
              initialEntries={[initialPath]}
              future={{ v7_startTransition: true, v7_relativeSplatPath: true }}
            >
              <Routes>
                <Route path="/experiments/:id" element={children} />
              </Routes>
            </MemoryRouter>
          </WebSocketProvider>
        </AuthProvider>
      </QueryClientProvider>
    </StrictMode>
  );
}

describe("Experiment detail realtime rendering", () => {
  beforeEach(() => {
    localStorage.clear();
    localStorage.setItem("auth_token", "test-token");
    vi.clearAllMocks();

    vi.mocked(api.get).mockImplementation(async (path: string) => {
      switch (path) {
        case "/api/v1/auth/me":
          return {
            data: {
              id: "user-1",
              email: "admin@local.dev",
              role: "admin",
              tenant_id: "tenant-1",
            },
          };

        case "/api/v1/experiments/exp-1":
          return {
            id: "exp-1",
            key: "browser-pass-exp",
            name: "Browser Pass Experiment",
            hypothesis: "Treatment improves engagement.",
            status: "running",
            version: 2,
            archived: false,
            variants: [
              {
                id: "variant-control",
                key: "control",
                name: "Control",
                is_control: true,
                traffic_allocation: 5000,
                sort_order: 0,
              },
              {
                id: "variant-treatment",
                key: "treatment",
                name: "Treatment",
                is_control: false,
                traffic_allocation: 5000,
                sort_order: 1,
              },
            ],
            metrics: [
              {
                id: "metric-1",
                key: "browser_pass_conversion",
                name: "Browser Pass Conversion",
                role: "primary",
                metric_type: "count",
              },
            ],
            inserted_at: "2026-06-04T07:12:48Z",
            updated_at: "2026-06-04T11:47:17Z",
            started_at: "2026-06-04T11:47:17Z",
          };

        case "/api/v1/experiments/exp-1/results":
          return {
            experiment_id: "exp-1",
            computed_at: "2026-06-04T11:47:58Z",
            computation_time_ms: 0,
            overall_status: "insufficient_data",
            has_sufficient_data: false,
            guardrail_breaches: [],
            metrics: [
              {
                metric_key: "browser_pass_conversion",
                metric_type: "count",
                role: "primary",
                frequentist: {
                  test_method: "z_test_proportions",
                  p_value: 0.1529,
                  confidence_level: 0.95,
                  confidence_interval: {
                    lower: -0.0074,
                    upper: 0.0474,
                    point_estimate: 0.02,
                  },
                  effect_size: {
                    absolute: 0.02,
                    relative: 0.2,
                    cohens_h: 0.064,
                  },
                  power_achieved: 0.298,
                  is_significant: false,
                },
                sequential: {
                  spending_function: "obrien_fleming",
                  information_fraction: 0.26,
                  nominal_alpha: 0.0001,
                  adjusted_critical_value: 3.84,
                  observed_z_statistic: 2.86,
                  can_reject: false,
                },
                sample_size_calculation: {
                  minimum_required: 3839,
                  current_total: 2000,
                  is_sufficient: false,
                  baseline_rate: 0.1,
                  minimum_detectable_effect: 0.02,
                  power: 0.8,
                  significance_level: 0.05,
                },
                recommendation: {
                  action: "insufficient_data",
                  message: "Only 2000 of 7678 required samples collected. Continue running.",
                },
                variants: [
                  {
                    variant_key: "control",
                    sample_size: 1000,
                    conversions: 100,
                    conversion_rate: 0.1,
                    mean: 0.1,
                  },
                  {
                    variant_key: "treatment",
                    sample_size: 1000,
                    conversions: 120,
                    conversion_rate: 0.12,
                    mean: 0.12,
                  },
                ],
              },
            ],
          };

        default:
          throw new Error(`Unexpected GET ${path}`);
      }
    });
  });

  afterEach(() => {
    localStorage.clear();
  });

  it("bootstraps auth, keeps the websocket connected under StrictMode, and renders persisted experiment results", async () => {
    const { unmount } = render(<ExperimentDetailPage />, {
      wrapper: createWrapper(),
    });

    expect(await screen.findByText("Browser Pass Experiment")).toBeInTheDocument();
    expect(await screen.findByRole("button", { name: "Pause" })).toBeInTheDocument();
    expect(screen.getByText("Statistical Significance")).toBeInTheDocument();
    expect(screen.getByText("Only 2000 of 7678 required samples collected. Continue running.")).toBeInTheDocument();
    expect(screen.getByText("Confidence Interval Chart")).toBeInTheDocument();
    expect(screen.getByText("Conversion Rate Over Time")).toBeInTheDocument();
    expect(screen.queryByText("Analysis Pending")).not.toBeInTheDocument();

    await waitFor(() => expect(socketSpies.connect).toHaveBeenCalledTimes(1));
    expect(socketSpies.disconnect).not.toHaveBeenCalled();
    expect(socketSpies.channel).toHaveBeenCalledWith("experiment:exp-1");

    unmount();

    await waitFor(() => expect(socketSpies.disconnect).toHaveBeenCalledTimes(1));
  });
});