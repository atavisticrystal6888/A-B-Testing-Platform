import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import type { ReactNode } from 'react';
import ConversionOverTimeChart from '../../src/components/charts/ConversionOverTimeChart';

// jsdom's getBoundingClientRect always returns all-zero dimensions, so
// recharts' <ResponsiveContainer> (which measures its container with it on
// mount, before rendering any children) never mounts the chart — scoped to
// this file only, since no other suite renders recharts. Only the
// ResponsiveContainer's own <div> needs the real chart-sized rect; giving
// every element (including axis tick <text> nodes) that same huge size
// would make recharts' own tick-overlap avoidance think every tick
// collides, collapsing the y-axis down to a single label regardless of
// domain — so tick-sized elements get a small, realistic rect instead.
Element.prototype.getBoundingClientRect = vi.fn(function (this: Element) {
  const isMeasuredContainer = this.tagName === 'DIV';
  const width = isMeasuredContainer ? 600 : 40;
  const height = isMeasuredContainer ? 250 : 11;
  return {
    width,
    height,
    top: 0,
    left: 0,
    bottom: height,
    right: width,
    x: 0,
    y: 0,
    toJSON() {},
  };
});

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

const twoVariantResponse = {
  data: {
    metric_key: 'signup-rate',
    metric_name: 'Signup Rate',
    series: [
      {
        date: '2026-08-20',
        variants: [
          { variant_key: 'control', sample_size: 100, conversions: 10, conversion_rate: 0.1 },
          { variant_key: 'treatment', sample_size: 100, conversions: 20, conversion_rate: 0.2 },
        ],
      },
      {
        date: '2026-08-21',
        variants: [
          { variant_key: 'control', sample_size: 120, conversions: 15, conversion_rate: 0.125 },
          { variant_key: 'treatment', sample_size: 130, conversions: 39, conversion_rate: 0.3 },
        ],
      },
    ],
  },
};

describe('ConversionOverTimeChart', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('fetches real daily-results data and renders a line per variant with the real latest rate in the aria-label', async () => {
    vi.mocked(api.get).mockResolvedValue(twoVariantResponse);

    render(<ConversionOverTimeChart experimentId="exp-1" />, { wrapper: createWrapper() });

    const figure = await screen.findByRole('img');

    expect(api.get).toHaveBeenCalledWith('/api/v1/experiments/exp-1/daily-results');

    // Latest day is 2026-08-21: control 12.50%, treatment 30.00%. These are
    // the REAL fetched rates, not the fabricated Math.random() values the
    // old component produced.
    expect(figure).toHaveAttribute('aria-label', expect.stringContaining('12.50%'));
    expect(figure).toHaveAttribute('aria-label', expect.stringContaining('30.00%'));

    expect(screen.getByText('control')).toBeInTheDocument();
    expect(screen.getByText('treatment')).toBeInTheDocument();
  });

  it('renders the empty state when there are no daily rollups yet', async () => {
    vi.mocked(api.get).mockResolvedValue({
      data: { metric_key: null, metric_name: null, series: [] },
    });

    render(<ConversionOverTimeChart experimentId="exp-1" />, { wrapper: createWrapper() });

    expect(await screen.findByText('No daily rollups yet')).toBeInTheDocument();
    expect(
      screen.getByText(
        'Daily conversion rollups appear once the data pipeline has processed events for this experiment.',
      ),
    ).toBeInTheDocument();
    expect(screen.queryByRole('img')).not.toBeInTheDocument();
  });

  it('renders an error state when the daily-results request fails', async () => {
    vi.mocked(api.get).mockRejectedValue(new Error('network down'));

    render(<ConversionOverTimeChart experimentId="exp-1" />, { wrapper: createWrapper() });

    expect(await screen.findByText('Unable to load conversion data.')).toBeInTheDocument();
  });

  it('anchors the y-axis domain at 0, even when every observed rate is well above it', async () => {
    vi.mocked(api.get).mockResolvedValue({
      data: {
        metric_key: 'signup-rate',
        metric_name: 'Signup Rate',
        series: [
          {
            date: '2026-08-20',
            variants: [{ variant_key: 'control', sample_size: 100, conversions: 80, conversion_rate: 0.8 }],
          },
          {
            date: '2026-08-21',
            variants: [{ variant_key: 'control', sample_size: 100, conversions: 90, conversion_rate: 0.9 }],
          },
        ],
      },
    });

    const { container } = render(<ConversionOverTimeChart experimentId="exp-1" />, {
      wrapper: createWrapper(),
    });
    await screen.findByRole('img');

    // With domain [0, 'auto'] recharts always includes a tick at the floor;
    // the old dropped-domain behavior (default [dataMin, dataMax]) would
    // start around 80%, never showing 0.0%.
    const tickLabels = Array.from(
      container.querySelectorAll('.recharts-yAxis .recharts-cartesian-axis-tick-value'),
    ).map((el) => el.textContent);
    expect(tickLabels).toContain('0.0%');
  });

  it('renders a gap without crashing when one variant has no rollup row for a date', async () => {
    vi.mocked(api.get).mockResolvedValue({
      data: {
        metric_key: 'signup-rate',
        metric_name: 'Signup Rate',
        series: [
          {
            date: '2026-08-20',
            variants: [
              { variant_key: 'control', sample_size: 100, conversions: 10, conversion_rate: 0.1 },
              { variant_key: 'treatment', sample_size: 100, conversions: 20, conversion_rate: 0.2 },
            ],
          },
          {
            date: '2026-08-21',
            // treatment has no rollup row for this date at all.
            variants: [{ variant_key: 'control', sample_size: 120, conversions: 15, conversion_rate: 0.125 }],
          },
        ],
      },
    });

    render(<ConversionOverTimeChart experimentId="exp-1" />, { wrapper: createWrapper() });

    await screen.findByRole('img');
    expect(screen.getByText('control')).toBeInTheDocument();
    expect(screen.getByText('treatment')).toBeInTheDocument();
  });
});
