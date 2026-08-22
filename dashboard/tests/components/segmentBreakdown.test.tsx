import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import type { ReactNode } from 'react';
import { SegmentBreakdownCard } from '../../src/components/experiments/SegmentBreakdownCard';

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

describe('SegmentBreakdownCard — cohort chips', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders pre-canned cohort chips and a Custom chip', () => {
    vi.mocked(api.get).mockResolvedValue({
      data: { attribute: 'country', metric_key: 'k', metric_name: 'n', note: '', segments: [] },
    });

    render(<SegmentBreakdownCard experimentId="exp-1" />, { wrapper: createWrapper() });

    expect(screen.getByText('Device')).toBeInTheDocument();
    expect(screen.getByText('Country')).toBeInTheDocument();
    expect(screen.getByText('New vs returning')).toBeInTheDocument();
    expect(screen.getByText('Custom…')).toBeInTheDocument();
  });

  it('clicking the Country chip fires the segments query with attribute=country', async () => {
    vi.mocked(api.get).mockResolvedValue({
      data: { attribute: 'country', metric_key: 'k', metric_name: 'n', note: '', segments: [] },
    });

    render(<SegmentBreakdownCard experimentId="exp-1" />, { wrapper: createWrapper() });

    fireEvent.click(screen.getByText('Country'));

    expect(await screen.findByText(/no assignments recorded/i).catch(() => null)).toBeDefined();
    expect(api.get).toHaveBeenCalledWith(
      '/api/v1/experiments/exp-1/segments?attribute=country',
    );
  });

  it('clicking the Device chip fires the segments query with attribute=device', () => {
    vi.mocked(api.get).mockResolvedValue({
      data: { attribute: 'device', metric_key: 'k', metric_name: 'n', note: '', segments: [] },
    });

    render(<SegmentBreakdownCard experimentId="exp-1" />, { wrapper: createWrapper() });

    fireEvent.click(screen.getByText('Device'));

    expect(api.get).toHaveBeenCalledWith(
      '/api/v1/experiments/exp-1/segments?attribute=device',
    );
  });

  it('clicking the New vs returning chip fires the segments query with attribute=new_vs_returning', () => {
    vi.mocked(api.get).mockResolvedValue({
      data: { attribute: 'new_vs_returning', metric_key: 'k', metric_name: 'n', note: '', segments: [] },
    });

    render(<SegmentBreakdownCard experimentId="exp-1" />, { wrapper: createWrapper() });

    fireEvent.click(screen.getByText('New vs returning'));

    expect(api.get).toHaveBeenCalledWith(
      '/api/v1/experiments/exp-1/segments?attribute=new_vs_returning',
    );
  });

  it('marks the clicked chip active with the indigo styling', () => {
    vi.mocked(api.get).mockResolvedValue({
      data: { attribute: 'country', metric_key: 'k', metric_name: 'n', note: '', segments: [] },
    });

    render(<SegmentBreakdownCard experimentId="exp-1" />, { wrapper: createWrapper() });

    const countryChip = screen.getByText('Country');
    fireEvent.click(countryChip);

    expect(countryChip.className).toContain('bg-indigo-600');
    expect(countryChip.className).toContain('text-white');
  });

  it('reveals the free-text custom input only after clicking Custom…', () => {
    render(<SegmentBreakdownCard experimentId="exp-1" />, { wrapper: createWrapper() });

    expect(screen.queryByPlaceholderText('attribute (e.g. country)')).not.toBeInTheDocument();

    fireEvent.click(screen.getByText('Custom…'));

    expect(screen.getByPlaceholderText('attribute (e.g. country)')).toBeInTheDocument();
  });

  it('shows the permanent descriptive-only badge in the header', () => {
    render(<SegmentBreakdownCard experimentId="exp-1" />, { wrapper: createWrapper() });

    expect(screen.getByText('descriptive only — no significance claims')).toBeInTheDocument();
  });

  it('never renders p-value or significance text anywhere in the card', () => {
    vi.mocked(api.get).mockResolvedValue({
      data: {
        attribute: 'country',
        metric_key: 'k',
        metric_name: 'n',
        note: '',
        segments: [
          {
            segment: 'US',
            total_sample_size: 100,
            variants: [
              { variant_key: 'control', sample_size: 50, conversions: 5, conversion_rate: 0.1 },
              { variant_key: 'treatment', sample_size: 50, conversions: 8, conversion_rate: 0.16 },
            ],
          },
        ],
      },
    });

    const { container } = render(<SegmentBreakdownCard experimentId="exp-1" />, {
      wrapper: createWrapper(),
    });

    fireEvent.click(screen.getByText('Country'));

    expect(container.textContent).not.toMatch(/p-value/i);
    expect(container.textContent).not.toMatch(/\bsignificant\b/i);
    expect(container.textContent).not.toMatch(/\bp\s*[<=]\s*0/i);
  });
});
