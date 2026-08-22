import type { ReactNode } from "react";

interface LoadingStateProps {
  label?: string;
  className?: string;
}

/** Spinner + label for an in-flight query. Marked `aria-busy` for a11y. */
export function LoadingState({ label = "Loading...", className = "py-12" }: LoadingStateProps) {
  return (
    <div
      className={`flex items-center justify-center gap-3 text-sm text-gray-500 ${className}`}
      aria-busy="true"
      role="status"
    >
      <svg
        className="h-4 w-4 animate-spin text-indigo-500"
        viewBox="0 0 24 24"
        fill="none"
        aria-hidden="true"
      >
        <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
        <path
          className="opacity-75"
          fill="currentColor"
          d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
        />
      </svg>
      <span>{label}</span>
    </div>
  );
}

interface ErrorStateProps {
  error?: unknown;
  onRetry?: () => void;
  message?: string;
  className?: string;
}

function messageFromError(error: unknown): string | undefined {
  if (error instanceof Error && error.message) {
    return error.message;
  }

  return undefined;
}

/** Message + retry (wired to a query's `refetch`) for a failed query. */
export function ErrorState({ error, onRetry, message, className = "py-8" }: ErrorStateProps) {
  const text = message ?? messageFromError(error) ?? "Something went wrong. Please try again.";

  return (
    <div
      className={`rounded-xl border border-red-200 bg-red-50 px-6 text-center text-sm text-red-700 ${className}`}
    >
      <p>{text}</p>
      {onRetry && (
        <button
          onClick={onRetry}
          className="mt-3 inline-flex items-center px-3 py-1.5 text-xs font-medium text-red-700 bg-white border border-red-300 rounded-lg hover:bg-red-100 transition-colors"
        >
          Retry
        </button>
      )}
    </div>
  );
}

interface EmptyStateProps {
  title: string;
  hint?: string;
  cta?: ReactNode;
  className?: string;
}

/** Message (+ optional hint and CTA) for a query that resolved with no data. */
export function EmptyState({ title, hint, cta, className = "py-12" }: EmptyStateProps) {
  return (
    <div className={`text-center ${className}`}>
      <p className="text-gray-500">{title}</p>
      {hint && <p className="text-sm text-gray-400 mt-1">{hint}</p>}
      {cta && <div className="mt-4">{cta}</div>}
    </div>
  );
}
