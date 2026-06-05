import { Link } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { useExperiments } from '../hooks/useExperiments';
import { api } from '../lib/api';
import type { ExperimentStatus, ExperimentSummary } from '../lib/types';

interface PlatformOverview {
  experiments: {
    total: number;
    draft: number;
    running: number;
    paused: number;
    concluded: number;
  };
  feature_flags: {
    total: number;
    enabled: number;
    disabled: number;
  };
  assignments: {
    total: number;
    today: number;
  };
  timestamp: string;
}

interface AuditLogItem {
  id: string;
  actor_id: string | null;
  actor_type: string;
  action: string;
  resource_type: string;
  resource_id: string;
  changes: Record<string, unknown>;
  reason?: string;
  timestamp: string;
}

const STATUS_STYLES: Record<ExperimentStatus, string> = {
  draft: 'bg-slate-100 text-slate-700',
  running: 'bg-emerald-100 text-emerald-700',
  paused: 'bg-amber-100 text-amber-700',
  concluded: 'bg-sky-100 text-sky-700',
};

const PORTFOLIO_TONES: Record<ExperimentStatus, string> = {
  draft: 'bg-slate-500',
  running: 'bg-emerald-500',
  paused: 'bg-amber-500',
  concluded: 'bg-sky-500',
};

function formatRelativeTime(value?: string) {
  if (!value) {
    return 'No timestamp available';
  }

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return 'Unknown time';
  }

  const diffMs = Date.now() - date.getTime();
  const diffMinutes = Math.round(diffMs / 60_000);

  if (diffMinutes < 1) {
    return 'Just now';
  }

  if (diffMinutes < 60) {
    return `${diffMinutes}m ago`;
  }

  const diffHours = Math.round(diffMinutes / 60);

  if (diffHours < 24) {
    return `${diffHours}h ago`;
  }

  const diffDays = Math.round(diffHours / 24);

  if (diffDays < 7) {
    return `${diffDays}d ago`;
  }

  return date.toLocaleDateString();
}

function humanize(value: string) {
  return value
    .replace(/_/g, ' ')
    .replace(/\b\w/g, (match) => match.toUpperCase());
}

function summarizeLog(log: AuditLogItem) {
  const statusChange = log.changes.status;

  if (statusChange && typeof statusChange === 'object' && !Array.isArray(statusChange)) {
    const from = (statusChange as { from?: unknown }).from;
    const to = (statusChange as { to?: unknown }).to;

    if (typeof from === 'string' && typeof to === 'string') {
      return `Status changed from ${from} to ${to}.`;
    }
  }

  return log.reason || humanize(log.action);
}

function resourceLabel(log: AuditLogItem, experiments: ExperimentSummary[]) {
  const matchingExperiment = experiments.find((experiment) => experiment.id === log.resource_id);

  if (matchingExperiment) {
    return matchingExperiment.name;
  }

  if (log.resource_type === 'experiment') {
    return `Experiment ${log.resource_id.slice(0, 8)}`;
  }

  return `${humanize(log.resource_type)} ${log.resource_id.slice(0, 8)}`;
}

function StatusBadge({ status }: { status: ExperimentStatus }) {
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium ${STATUS_STYLES[status]}`}>
      {humanize(status)}
    </span>
  );
}

export function PlatformDashboardPage() {
  const overviewQuery = useQuery<PlatformOverview>({
    queryKey: ['platform-overview'],
    queryFn: () =>
      api
        .get<{ data: PlatformOverview }>('/api/v1/analytics/overview')
        .then((response) => response.data),
  });

  const recentExperimentsQuery = useExperiments({
    page_size: '6',
    sort: 'inserted_at',
    order: 'desc',
  });

  const activityQuery = useQuery<AuditLogItem[]>({
    queryKey: ['dashboard-activity'],
    queryFn: () =>
      api
        .get<{ data: AuditLogItem[] }>('/api/v1/audit-logs?limit=8')
        .then((response) => response.data),
  });

  if (overviewQuery.isLoading) {
    return <div className="flex h-64 items-center justify-center text-sm text-gray-500">Loading dashboard...</div>;
  }

  if (overviewQuery.isError || !overviewQuery.data) {
    return (
      <div className="mx-auto max-w-7xl px-4 py-8">
        <div className="rounded-2xl border border-red-200 bg-red-50 p-6 text-sm text-red-700">
          Unable to load the platform dashboard right now.
        </div>
      </div>
    );
  }

  const overview = overviewQuery.data;
  const recentExperiments = recentExperimentsQuery.data?.data ?? [];
  const recentActivity = activityQuery.data ?? [];
  const guardrailAlerts = recentActivity.filter((log: AuditLogItem) => log.action === 'guardrail_breach');

  const metricCards = [
    {
      label: 'Running Experiments',
      value: overview.experiments.running,
      detail: `${overview.experiments.total} total in portfolio`,
      accent: 'text-emerald-200',
    },
    {
      label: 'Draft Queue',
      value: overview.experiments.draft,
      detail: `${overview.experiments.paused} paused and waiting`,
      accent: 'text-amber-200',
    },
    {
      label: 'Assignments Today',
      value: overview.assignments.today,
      detail: `${overview.assignments.total.toLocaleString()} total assignments`,
      accent: 'text-cyan-200',
    },
    {
      label: 'Enabled Flags',
      value: overview.feature_flags.enabled,
      detail: `${overview.feature_flags.total} flags configured`,
      accent: 'text-sky-200',
    },
  ];

  const portfolioRows: Array<{ label: string; status: ExperimentStatus; count: number }> = [
    { label: 'Draft', status: 'draft', count: overview.experiments.draft },
    { label: 'Running', status: 'running', count: overview.experiments.running },
    { label: 'Paused', status: 'paused', count: overview.experiments.paused },
    { label: 'Concluded', status: 'concluded', count: overview.experiments.concluded },
  ];

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <section className="overflow-hidden rounded-[28px] bg-linear-to-br from-slate-950 via-slate-900 to-emerald-800 p-8 text-white shadow-xl">
        <div className="flex flex-col gap-8 lg:flex-row lg:items-end lg:justify-between">
          <div className="max-w-2xl">
            <p className="text-xs font-semibold uppercase tracking-[0.32em] text-emerald-200">Experiment Command Center</p>
            <h1 className="mt-4 text-3xl font-semibold tracking-tight sm:text-4xl">
              Track launches, guardrails, and operational drift from one place.
            </h1>
            <p className="mt-4 max-w-xl text-sm leading-6 text-slate-200">
              This dashboard pairs live portfolio metrics with recent lifecycle activity so the next operational action is obvious.
            </p>
          </div>

          <div className="flex flex-wrap gap-3">
            <Link
              to="/experiments/new"
              className="inline-flex items-center rounded-full bg-white px-5 py-2.5 text-sm font-medium text-slate-900 transition hover:bg-slate-100"
            >
              Create Experiment
            </Link>
            <Link
              to="/audit-logs"
              className="inline-flex items-center rounded-full border border-white/20 bg-white/10 px-5 py-2.5 text-sm font-medium text-white transition hover:bg-white/15"
            >
              Open Audit Trail
            </Link>
          </div>
        </div>

        <div className="mt-8 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
          {metricCards.map((card) => (
            <div key={card.label} className="rounded-2xl border border-white/10 bg-white/10 p-5 backdrop-blur-sm">
              <p className="text-xs uppercase tracking-[0.22em] text-slate-200">{card.label}</p>
              <p className={`mt-3 text-4xl font-semibold ${card.accent}`}>{card.value}</p>
              <p className="mt-2 text-sm text-slate-300">{card.detail}</p>
            </div>
          ))}
        </div>

        <div className="mt-6 text-xs text-slate-300">
          Last refreshed {formatRelativeTime(overview.timestamp)}
        </div>
      </section>

      <div className="mt-8 grid gap-6 xl:grid-cols-[1.2fr_0.8fr]">
        <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
          <div className="flex items-center justify-between gap-4">
            <div>
              <h2 className="text-lg font-semibold text-slate-900">Recent Experiments</h2>
              <p className="mt-1 text-sm text-slate-500">Newest experiments and the next action each one needs.</p>
            </div>
            <Link to="/experiments" className="text-sm font-medium text-slate-700 transition hover:text-slate-900">
              View all
            </Link>
          </div>

          <div className="mt-6 space-y-3">
            {recentExperimentsQuery.isLoading ? (
              <div className="rounded-2xl border border-dashed border-slate-200 bg-slate-50 px-4 py-8 text-center text-sm text-slate-500">
                Loading experiments...
              </div>
            ) : recentExperimentsQuery.isError ? (
              <div className="rounded-2xl border border-red-200 bg-red-50 px-4 py-8 text-center text-sm text-red-600">
                Unable to load recent experiments.
              </div>
            ) : recentExperiments.length === 0 ? (
              <div className="rounded-2xl border border-dashed border-slate-200 bg-slate-50 px-4 py-8 text-center text-sm text-slate-500">
                No experiments yet. Create your first draft to start building the portfolio.
              </div>
            ) : (
              recentExperiments.map((experiment: ExperimentSummary) => {
                const nextAction =
                  experiment.status === 'draft'
                    ? 'Finish setup'
                    : experiment.status === 'running'
                    ? 'Monitor results'
                    : experiment.status === 'paused'
                    ? 'Review next step'
                    : 'Read summary';

                return (
                  <Link
                    key={experiment.id}
                    to={`/experiments/${experiment.id}`}
                    className="flex items-center justify-between gap-4 rounded-2xl border border-slate-200 px-4 py-4 transition hover:border-slate-300 hover:bg-slate-50"
                  >
                    <div className="min-w-0">
                      <div className="flex flex-wrap items-center gap-3">
                        <p className="truncate text-sm font-semibold text-slate-900">{experiment.name}</p>
                        <StatusBadge status={experiment.status} />
                      </div>
                      <p className="mt-1 text-xs font-mono text-slate-500">{experiment.key}</p>
                      <p className="mt-2 text-sm text-slate-500">
                        {experiment.variant_count} variants • {formatRelativeTime(experiment.started_at || experiment.inserted_at)}
                      </p>
                    </div>
                    <div className="shrink-0 text-sm font-medium text-slate-700">{nextAction}</div>
                  </Link>
                );
              })
            )}
          </div>
        </section>

        <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
          <div>
            <h2 className="text-lg font-semibold text-slate-900">Portfolio Snapshot</h2>
            <p className="mt-1 text-sm text-slate-500">A fast read on where experiments are sitting in the lifecycle.</p>
          </div>

          <div className="mt-6 space-y-4">
            {portfolioRows.map((row) => {
              const percentage = overview.experiments.total === 0 ? 0 : (row.count / overview.experiments.total) * 100;

              return (
                <div key={row.status}>
                  <div className="mb-2 flex items-center justify-between text-sm text-slate-600">
                    <span>{row.label}</span>
                    <span>{row.count}</span>
                  </div>
                  <div className="h-2 overflow-hidden rounded-full bg-slate-100">
                    <div className={`h-full rounded-full ${PORTFOLIO_TONES[row.status]}`} style={{ width: `${percentage}%` }} />
                  </div>
                </div>
              );
            })}
          </div>

          <div className="mt-8 rounded-2xl bg-slate-50 p-4">
            <p className="text-xs font-semibold uppercase tracking-[0.22em] text-slate-500">Signal Coverage</p>
            <div className="mt-4 grid grid-cols-2 gap-3 text-sm">
              <div className="rounded-2xl bg-white p-4">
                <p className="text-slate-500">Assignments total</p>
                <p className="mt-2 text-2xl font-semibold text-slate-900">{overview.assignments.total.toLocaleString()}</p>
              </div>
              <div className="rounded-2xl bg-white p-4">
                <p className="text-slate-500">Flags disabled</p>
                <p className="mt-2 text-2xl font-semibold text-slate-900">{overview.feature_flags.disabled}</p>
              </div>
            </div>
          </div>
        </section>
      </div>

      <div className="mt-6 grid gap-6 xl:grid-cols-[1.1fr_0.9fr]">
        <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
          <div className="flex items-center justify-between gap-4">
            <div>
              <h2 className="text-lg font-semibold text-slate-900">Recent Activity</h2>
              <p className="mt-1 text-sm text-slate-500">Latest lifecycle events across the tenant.</p>
            </div>
            <Link to="/audit-logs" className="text-sm font-medium text-slate-700 transition hover:text-slate-900">
              Open logs
            </Link>
          </div>

          <div className="mt-6 space-y-3">
            {activityQuery.isLoading ? (
              <div className="rounded-2xl border border-dashed border-slate-200 bg-slate-50 px-4 py-8 text-center text-sm text-slate-500">
                Loading audit activity...
              </div>
            ) : activityQuery.isError ? (
              <div className="rounded-2xl border border-red-200 bg-red-50 px-4 py-8 text-center text-sm text-red-600">
                Unable to load recent activity.
              </div>
            ) : recentActivity.length === 0 ? (
              <div className="rounded-2xl border border-dashed border-slate-200 bg-slate-50 px-4 py-8 text-center text-sm text-slate-500">
                No activity has been recorded yet.
              </div>
            ) : (
              recentActivity.map((log: AuditLogItem) => (
                <div key={log.id} className="rounded-2xl border border-slate-200 px-4 py-4">
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div>
                      <p className="text-sm font-semibold text-slate-900">{resourceLabel(log, recentExperiments)}</p>
                      <p className="mt-1 text-sm text-slate-600">{summarizeLog(log)}</p>
                    </div>
                    <div className="text-right text-xs text-slate-500">
                      <div>{humanize(log.action)}</div>
                      <div className="mt-1">{formatRelativeTime(log.timestamp)}</div>
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>
        </section>

        <div className="space-y-6">
          <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <div>
              <h2 className="text-lg font-semibold text-slate-900">Guardrail Alerts</h2>
              <p className="mt-1 text-sm text-slate-500">Recent automated pauses and health interventions.</p>
            </div>

            <div className="mt-6 space-y-3">
              {activityQuery.isLoading ? (
                <div className="rounded-2xl border border-dashed border-slate-200 bg-slate-50 px-4 py-8 text-center text-sm text-slate-500">
                  Checking alerts...
                </div>
              ) : guardrailAlerts.length === 0 ? (
                <div className="rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-8 text-center text-sm text-emerald-700">
                  No recent guardrail breaches detected.
                </div>
              ) : (
                guardrailAlerts.map((alert: AuditLogItem) => (
                  <div key={alert.id} className="rounded-2xl border border-amber-200 bg-amber-50 px-4 py-4">
                    <div className="flex items-start justify-between gap-3">
                      <div>
                        <p className="text-sm font-semibold text-amber-900">{resourceLabel(alert, recentExperiments)}</p>
                        <p className="mt-1 text-sm text-amber-800">{summarizeLog(alert)}</p>
                      </div>
                      <span className="rounded-full bg-amber-100 px-2.5 py-1 text-xs font-medium text-amber-800">
                        {formatRelativeTime(alert.timestamp)}
                      </span>
                    </div>
                  </div>
                ))
              )}
            </div>
          </section>

          <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <div>
              <h2 className="text-lg font-semibold text-slate-900">Lifecycle Shortcuts</h2>
              <p className="mt-1 text-sm text-slate-500">Jump straight to the next operational workflow.</p>
            </div>

            <div className="mt-6 grid gap-3 sm:grid-cols-2">
              <Link to="/experiments/new" className="rounded-2xl border border-slate-200 bg-slate-50 p-4 transition hover:border-slate-300 hover:bg-slate-100">
                <p className="text-sm font-semibold text-slate-900">Create a Draft</p>
                <p className="mt-2 text-sm text-slate-500">Set up a new experiment and move it into review.</p>
              </Link>
              <Link to="/experiments" className="rounded-2xl border border-slate-200 bg-slate-50 p-4 transition hover:border-slate-300 hover:bg-slate-100">
                <p className="text-sm font-semibold text-slate-900">Review Active Runs</p>
                <p className="mt-2 text-sm text-slate-500">Monitor {overview.experiments.running} running experiments and {overview.experiments.paused} paused ones.</p>
              </Link>
              <Link to="/audit-logs" className="rounded-2xl border border-slate-200 bg-slate-50 p-4 transition hover:border-slate-300 hover:bg-slate-100">
                <p className="text-sm font-semibold text-slate-900">Inspect Audit Trail</p>
                <p className="mt-2 text-sm text-slate-500">Trace recent state changes and automated interventions.</p>
              </Link>
              <Link to="/metrics" className="rounded-2xl border border-slate-200 bg-slate-50 p-4 transition hover:border-slate-300 hover:bg-slate-100">
                <p className="text-sm font-semibold text-slate-900">Review Metrics</p>
                <p className="mt-2 text-sm text-slate-500">Keep success metrics and guardrails aligned before launch.</p>
              </Link>
            </div>
          </section>
        </div>
      </div>
    </div>
  );
}
