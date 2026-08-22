import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, act } from '@testing-library/react';
import { ExportMenu } from '../../src/components/experiments/ExportMenu';
import type { Experiment, AnalysisResults } from '../../src/lib/types';

vi.mock('../../src/lib/api', async () => {
  const actual = await vi.importActual<typeof import('../../src/lib/api')>('../../src/lib/api');
  return {
    ...actual,
    api: {
      get: vi.fn(),
      post: vi.fn(),
      put: vi.fn(),
      delete: vi.fn(),
    },
  };
});

import { api } from '../../src/lib/api';

const experiment: Experiment = {
  id: 'exp-1',
  key: 'checkout-test',
  name: 'Checkout Test',
  hypothesis: 'New checkout flow improves conversion',
  status: 'running',
  version: 1,
  archived: false,
  variants: [],
  inserted_at: '2026-01-01T00:00:00Z',
  updated_at: '2026-01-01T00:00:00Z',
};

const results: AnalysisResults = {
  experiment_id: 'exp-1',
  computed_at: '2026-01-02T00:00:00Z',
  computation_time_ms: 10,
  metrics: [],
  overall_status: 'pending',
  has_sufficient_data: false,
  guardrail_breaches: [],
};

describe('ExportMenu — Copy share link', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    Object.defineProperty(navigator, 'clipboard', {
      value: { writeText: vi.fn().mockResolvedValue(undefined) },
      configurable: true,
    });
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('disables the button with a tooltip when results is undefined', () => {
    render(<ExportMenu experiment={experiment} />);

    const button = screen.getByText('Copy share link');
    expect(button).toBeDisabled();
    expect(button).toHaveAttribute(
      'title',
      expect.stringContaining('Analysis results are required'),
    );
  });

  it('is enabled when results are available', () => {
    render(<ExportMenu experiment={experiment} results={results} />);

    expect(screen.getByText('Copy share link')).not.toBeDisabled();
  });

  it('posts the readout html, copies the returned url, and reverts the label after 2s', async () => {
    vi.useFakeTimers();
    vi.mocked(api.post).mockResolvedValue({
      data: { url: 'http://localhost/share/readout/tok123' },
    });

    render(<ExportMenu experiment={experiment} results={results} />);

    await act(async () => {
      fireEvent.click(screen.getByText('Copy share link'));
      // Flush the api.post + clipboard.writeText promise chain — fake
      // timers only replace setTimeout/setInterval, not the microtask
      // queue, so awaiting a couple of resolved promises drains it.
      await Promise.resolve();
      await Promise.resolve();
      await Promise.resolve();
    });

    expect(api.post).toHaveBeenCalledWith('/api/v1/experiments/exp-1/share-readout', {
      html: expect.stringContaining('<!doctype html>'),
    });
    expect(navigator.clipboard.writeText).toHaveBeenCalledWith(
      'http://localhost/share/readout/tok123',
    );
    expect(screen.getByText('Link copied ✓')).toBeInTheDocument();

    act(() => {
      vi.advanceTimersByTime(2000);
    });

    expect(screen.getByText('Copy share link')).toBeInTheDocument();
  });

  it('falls back to a copyable URL input when clipboard.writeText rejects, without showing a failure message', async () => {
    vi.mocked(api.post).mockResolvedValue({
      data: { url: 'http://localhost/share/readout/tok456' },
    });
    vi.mocked(navigator.clipboard.writeText).mockRejectedValueOnce(
      new Error('document not focused'),
    );

    render(<ExportMenu experiment={experiment} results={results} />);

    await act(async () => {
      fireEvent.click(screen.getByText('Copy share link'));
      await Promise.resolve();
      await Promise.resolve();
      await Promise.resolve();
    });

    expect(screen.queryByText('Failed to create share link.')).not.toBeInTheDocument();

    const input = screen.getByDisplayValue('http://localhost/share/readout/tok456');
    expect(input).toHaveAttribute('readonly');

    const copyButton = screen.getByRole('button', { name: 'Copy' });
    fireEvent.click(copyButton);
    expect(navigator.clipboard.writeText).toHaveBeenCalledWith(
      'http://localhost/share/readout/tok456',
    );
  });

  it('surfaces an error message when the share request fails', async () => {
    vi.mocked(api.post).mockRejectedValue(new Error('network down'));

    render(<ExportMenu experiment={experiment} results={results} />);

    await act(async () => {
      fireEvent.click(screen.getByText('Copy share link'));
      await Promise.resolve();
      await Promise.resolve();
      await Promise.resolve();
    });

    expect(screen.getByText('Failed to create share link.')).toBeInTheDocument();
    expect(navigator.clipboard.writeText).not.toHaveBeenCalled();
  });
});
