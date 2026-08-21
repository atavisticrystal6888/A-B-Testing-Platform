import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import type { ReactNode } from 'react';
import { CreateExperimentPage } from '../../src/pages/CreateExperimentPage';

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
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>{children}</MemoryRouter>
    </QueryClientProvider>
  );
}

describe('CreateExperimentPage — Power calculator wizard step', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('fills baseline inputs, calls the power-estimate endpoint, and renders the result sentence', async () => {
    vi.mocked(api.post).mockResolvedValue({
      data: {
        sample_size_per_variant: 1200,
        total_sample_size: 2400,
        estimated_days: 5,
      },
    });

    render(<CreateExperimentPage />, { wrapper: createWrapper() });

    // Step 1 (Hypothesis) — name is required to advance; key auto-derives from it.
    fireEvent.change(screen.getByPlaceholderText('Checkout Button Color'), {
      target: { value: 'Test Experiment' },
    });
    fireEvent.click(screen.getByText('Next')); // -> Step 2 (Variants)
    fireEvent.click(screen.getByText('Next')); // -> Step 3 (Traffic, defaults to 100%)
    fireEvent.click(screen.getByText('Next')); // -> Step 4 (Power)

    expect(await screen.findByText('Power Calculator')).toBeInTheDocument();
    expect(screen.getByText(/Optional — estimates only/)).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText('Baseline conversion rate (%)'), {
      target: { value: '5' },
    });
    fireEvent.change(screen.getByLabelText('Minimum detectable effect (relative %)'), {
      target: { value: '10' },
    });

    fireEvent.click(screen.getByText('Calculate'));

    expect(await screen.findByText(/1,200 users per variant/)).toBeInTheDocument();
    expect(screen.getByText(/2,400 total/)).toBeInTheDocument();
    expect(screen.getByText(/~5 days/)).toBeInTheDocument();

    expect(api.post).toHaveBeenCalledWith(
      '/api/v1/power-estimate',
      expect.objectContaining({
        baseline_rate: 0.05,
        mde: 0.1,
        significance_level: 0.05,
        power: 0.8,
        num_variants: 2,
      }),
    );
  });

  it('omits the traffic sentence when estimated_days is null', async () => {
    vi.mocked(api.post).mockResolvedValue({
      data: {
        sample_size_per_variant: 800,
        total_sample_size: 1600,
        estimated_days: null,
      },
    });

    render(<CreateExperimentPage />, { wrapper: createWrapper() });

    fireEvent.change(screen.getByPlaceholderText('Checkout Button Color'), {
      target: { value: 'Test Experiment' },
    });
    fireEvent.click(screen.getByText('Next'));
    fireEvent.click(screen.getByText('Next'));
    fireEvent.click(screen.getByText('Next'));

    fireEvent.click(await screen.findByText('Calculate'));

    expect(await screen.findByText(/800 users per variant/)).toBeInTheDocument();
    expect(screen.queryByText(/days/)).not.toBeInTheDocument();
  });

  it('disables Calculate and shows an inline error when a required field is cleared', async () => {
    render(<CreateExperimentPage />, { wrapper: createWrapper() });

    fireEvent.change(screen.getByPlaceholderText('Checkout Button Color'), {
      target: { value: 'Test Experiment' },
    });
    fireEvent.click(screen.getByText('Next'));
    fireEvent.click(screen.getByText('Next'));
    fireEvent.click(screen.getByText('Next'));

    await screen.findByText('Power Calculator');

    fireEvent.change(screen.getByLabelText('Baseline conversion rate (%)'), {
      target: { value: '' },
    });

    expect(await screen.findByText(/baseline conversion rate is required/i)).toBeInTheDocument();
    expect(screen.getByText('Calculate')).toBeDisabled();
    expect(api.post).not.toHaveBeenCalled();
  });

  it('rejects an out-of-range baseline rate and keeps Calculate disabled', async () => {
    render(<CreateExperimentPage />, { wrapper: createWrapper() });

    fireEvent.change(screen.getByPlaceholderText('Checkout Button Color'), {
      target: { value: 'Test Experiment' },
    });
    fireEvent.click(screen.getByText('Next'));
    fireEvent.click(screen.getByText('Next'));
    fireEvent.click(screen.getByText('Next'));

    await screen.findByText('Power Calculator');

    fireEvent.change(screen.getByLabelText('Baseline conversion rate (%)'), {
      target: { value: '150' },
    });

    expect(await screen.findByText(/between 0% and 100%/i)).toBeInTheDocument();
    expect(screen.getByText('Calculate')).toBeDisabled();
    expect(api.post).not.toHaveBeenCalled();
  });
});
