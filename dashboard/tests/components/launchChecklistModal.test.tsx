import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import type { ReactNode } from 'react';
import { LaunchChecklistModal } from '../../src/components/experiments/LaunchChecklistModal';
import type { Experiment } from '../../src/lib/types';

vi.mock('../../src/lib/api', () => ({
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

import { api } from '../../src/lib/api';

function createWrapper() {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });

  return ({ children }: { children: ReactNode }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  );
}

function healthyExperiment(): Experiment {
  return {
    id: 'exp-1',
    key: 'exp-key',
    name: 'Checkout Button Color',
    hypothesis: 'Green converts better',
    status: 'draft',
    version: 1,
    archived: false,
    variants: [
      { id: 'v-1', key: 'control', name: 'Control', is_control: true, traffic_allocation: 5000, sort_order: 0 },
      { id: 'v-2', key: 'treatment', name: 'Treatment', is_control: false, traffic_allocation: 5000, sort_order: 1 },
    ],
    metrics: [{ id: 'm-1', key: 'signup_rate', role: 'primary' }],
    inserted_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
  };
}

describe('LaunchChecklistModal', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('enables "Start experiment" and hides the override path when every check passes', async () => {
    vi.mocked(api.get).mockResolvedValue({
      data: {
        lifecycle: [],
        daily_exposures: [{ date: new Date().toISOString().slice(0, 10), count: 5 }],
      },
    });

    const onConfirm = vi.fn();
    render(
      <LaunchChecklistModal
        experiment={healthyExperiment()}
        onConfirm={onConfirm}
        onCancel={vi.fn()}
      />,
      { wrapper: createWrapper() },
    );

    const startButton = await screen.findByRole('button', { name: 'Start experiment' });
    expect(startButton).not.toBeDisabled();
    expect(screen.queryByRole('button', { name: 'Start anyway' })).not.toBeInTheDocument();

    fireEvent.click(startButton);
    expect(onConfirm).toHaveBeenCalledTimes(1);
  });

  it('shows "Start experiment" ENABLED for a draft experiment with primary metric and full allocation, even though exposures is unknown', async () => {
    // healthyExperiment() is status: "draft" with a primary metric attached
    // and 5000/5000 allocation. Timeline data (with a today-dated exposure)
    // is deliberately provided to prove the draft-exposures-are-unknown
    // rule wins regardless of what the timeline says — it must not read as
    // "pass" just because there happens to be recent exposure data.
    vi.mocked(api.get).mockResolvedValue({
      data: {
        lifecycle: [],
        daily_exposures: [{ date: new Date().toISOString().slice(0, 10), count: 5 }],
      },
    });

    render(
      <LaunchChecklistModal experiment={healthyExperiment()} onConfirm={vi.fn()} onCancel={vi.fn()} />,
      { wrapper: createWrapper() },
    );

    const startButton = await screen.findByRole('button', { name: 'Start experiment' });
    expect(startButton).not.toBeDisabled();
    expect(screen.queryByRole('button', { name: 'Start anyway' })).not.toBeInTheDocument();
    expect(screen.getByText("Couldn't verify")).toBeInTheDocument();
  });

  it('disables "Start experiment" and requires explicit override confirmation when a check fails', async () => {
    // No primary metric attached -> primary_metric check fails.
    const experiment = healthyExperiment();
    experiment.metrics = [];
    vi.mocked(api.get).mockResolvedValue({
      data: {
        lifecycle: [],
        daily_exposures: [{ date: new Date().toISOString().slice(0, 10), count: 5 }],
      },
    });

    const onConfirm = vi.fn();
    render(
      <LaunchChecklistModal experiment={experiment} onConfirm={onConfirm} onCancel={vi.fn()} />,
      { wrapper: createWrapper() },
    );

    const startButton = await screen.findByRole('button', { name: 'Start experiment' });
    expect(startButton).toBeDisabled();

    const startAnywayButton = screen.getByRole('button', { name: 'Start anyway' });
    expect(onConfirm).not.toHaveBeenCalled();

    fireEvent.click(startAnywayButton);

    const confirmButton = await screen.findByRole('button', { name: /Start with \d+ unmet checks?\?/ });
    expect(onConfirm).not.toHaveBeenCalled();

    fireEvent.click(confirmButton);
    expect(onConfirm).toHaveBeenCalledTimes(1);
  });

  it('counts only "fail" items in the override label, not "unknown" ones', async () => {
    // healthyExperiment() is status "draft", so the exposures check is
    // always "unknown" (advisory, never blocking) regardless of timeline
    // data. With no primary metric attached, only primary_metric actually
    // fails — the override label must say "1", not "2".
    const experiment = healthyExperiment();
    experiment.metrics = [];
    vi.mocked(api.get).mockResolvedValue({
      data: {
        lifecycle: [],
        daily_exposures: [{ date: new Date().toISOString().slice(0, 10), count: 5 }],
      },
    });

    render(
      <LaunchChecklistModal experiment={experiment} onConfirm={vi.fn()} onCancel={vi.fn()} />,
      { wrapper: createWrapper() },
    );

    expect(await screen.findByText("Couldn't verify")).toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: 'Start anyway' }));

    expect(await screen.findByRole('button', { name: 'Start with 1 unmet check?' })).toBeInTheDocument();
  });

  it('renders the exposures check as "unknown" and does not block Start on its own when timeline data is unavailable', async () => {
    vi.mocked(api.get).mockRejectedValue(new Error('network error'));

    render(
      <LaunchChecklistModal experiment={healthyExperiment()} onConfirm={vi.fn()} onCancel={vi.fn()} />,
      { wrapper: createWrapper() },
    );

    expect(await screen.findByText("Couldn't verify")).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Start experiment' })).not.toBeDisabled();
  });

  it('calls onCancel when Cancel is clicked', async () => {
    vi.mocked(api.get).mockResolvedValue({ data: { lifecycle: [], daily_exposures: [] } });
    const onCancel = vi.fn();

    render(
      <LaunchChecklistModal experiment={healthyExperiment()} onConfirm={vi.fn()} onCancel={onCancel} />,
      { wrapper: createWrapper() },
    );

    fireEvent.click(screen.getByRole('button', { name: 'Cancel' }));
    expect(onCancel).toHaveBeenCalledTimes(1);
  });
});
