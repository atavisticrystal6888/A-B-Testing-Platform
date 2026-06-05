import { FormEvent, useMemo, useState } from "react";
import { Navigate } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import { ApiError } from "../lib/api";

function parseLoginError(error: unknown): string {
  if (!(error instanceof ApiError)) {
    return "Unable to sign in right now. Please try again.";
  }

  const body = error.body as { error?: string; message?: string } | null;

  if (body?.error === "tenant_required") {
    return "This email exists in multiple tenants. Please enter your tenant ID and try again.";
  }

  if (body?.message) {
    return body.message;
  }

  if (error.status === 401) {
    return "Invalid email or password.";
  }

  return "Unable to sign in right now. Please try again.";
}

export default function LoginPage() {
  const { login, isAuthenticated, isInitializing } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [tenantId, setTenantId] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const canSubmit = useMemo(
    () => !!email.trim() && !!password.trim() && !isSubmitting,
    [email, password, isSubmitting],
  );

  if (isInitializing) {
    return (
      <div className="min-h-screen bg-slate-50 flex items-center justify-center px-6">
        <p className="text-sm text-slate-600">Checking session...</p>
      </div>
    );
  }

  if (isAuthenticated) {
    return <Navigate to="/experiments" replace />;
  }

  const onSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setError(null);
    setIsSubmitting(true);

    try {
      await login(email.trim(), password, tenantId.trim() || undefined);
    } catch (err) {
      setError(parseLoginError(err));
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen bg-linear-to-br from-slate-100 via-white to-blue-50 flex items-center justify-center px-6 py-12">
      <div className="w-full max-w-md bg-white border border-slate-200 rounded-2xl shadow-lg p-8">
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-slate-900">ExperimentHub</h1>
          <p className="text-sm text-slate-600 mt-1">Sign in to manage experiments and results.</p>
        </div>

        <form onSubmit={onSubmit} className="space-y-4">
          <div>
            <label htmlFor="email" className="block text-sm font-medium text-slate-700 mb-1">
              Email
            </label>
            <input
              id="email"
              type="email"
              autoComplete="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-3 py-2.5 rounded-lg border border-slate-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              placeholder="you@company.com"
              required
            />
          </div>

          <div>
            <label htmlFor="password" className="block text-sm font-medium text-slate-700 mb-1">
              Password
            </label>
            <input
              id="password"
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-3 py-2.5 rounded-lg border border-slate-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              placeholder="Enter your password"
              required
            />
          </div>

          <div>
            <label htmlFor="tenant" className="block text-sm font-medium text-slate-700 mb-1">
              Tenant ID (optional)
            </label>
            <input
              id="tenant"
              type="text"
              value={tenantId}
              onChange={(e) => setTenantId(e.target.value)}
              className="w-full px-3 py-2.5 rounded-lg border border-slate-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              placeholder="Required for shared emails"
            />
          </div>

          {error && (
            <div className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
              {error}
            </div>
          )}

          <button
            type="submit"
            disabled={!canSubmit}
            className="w-full py-2.5 rounded-lg bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            {isSubmitting ? "Signing in..." : "Sign in"}
          </button>
        </form>
      </div>
    </div>
  );
}