import { Component, type ErrorInfo, type ReactNode } from "react";
import { Link } from "react-router-dom";

interface RouteErrorBoundaryProps {
  children: ReactNode;
}

interface RouteErrorBoundaryState {
  error: Error | null;
}

/**
 * Catches render errors thrown by routed page content and shows a recoverable
 * fallback instead of a blank screen. Mount it wrapping the routed content in
 * App.tsx, keyed by `location.pathname` so navigating away and back gives a
 * fresh boundary automatically.
 */
export class RouteErrorBoundary extends Component<RouteErrorBoundaryProps, RouteErrorBoundaryState> {
  state: RouteErrorBoundaryState = { error: null };

  static getDerivedStateFromError(error: Error): RouteErrorBoundaryState {
    return { error };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error("RouteErrorBoundary caught a render error:", error, errorInfo.componentStack);
  }

  handleRetry = () => {
    this.setState({ error: null });
  };

  render() {
    const { error } = this.state;

    if (error) {
      return (
        <div className="min-h-screen flex items-center justify-center p-8">
          <div className="max-w-md w-full bg-white rounded-xl border border-gray-200 shadow-sm p-6 text-center">
            <h1 className="text-lg font-semibold text-gray-900">Something went wrong on this page</h1>
            <p className="mt-2 text-sm text-gray-500">
              An unexpected error stopped this page from rendering.
            </p>
            <details className="mt-4 text-left text-xs text-gray-500">
              <summary className="cursor-pointer text-sm font-medium text-gray-600">Error details</summary>
              <p className="mt-2 whitespace-pre-wrap font-mono">{error.message}</p>
            </details>
            <div className="mt-6 flex items-center justify-center gap-3">
              <button
                onClick={this.handleRetry}
                className="px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700 transition-colors"
              >
                Try again
              </button>
              <Link
                to="/dashboard"
                className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Go to dashboard
              </Link>
            </div>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}

export default RouteErrorBoundary;
