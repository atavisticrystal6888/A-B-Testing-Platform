import { lazy, Suspense, type ReactNode } from "react";
import { BrowserRouter, Routes, Route, Navigate, Outlet, useLocation } from "react-router-dom";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { AuthProvider, useAuth } from "./contexts/AuthContext";
import { TenantProvider } from "./contexts/TenantContext";
import { WebSocketProvider } from "./contexts/WebSocketContext";
import { RouteErrorBoundary } from "./components/ui/RouteErrorBoundary";

const Layout = lazy(() => import("./pages/Layout"));
const LoginPage = lazy(() => import("./pages/LoginPage"));
const ExperimentListPage = lazy(() => import("./pages/ExperimentListPage"));
const ExperimentDetailPage = lazy(() => import("./pages/ExperimentDetailPage"));
const ExperimentTimelinePage = lazy(() => import("./pages/ExperimentTimelinePage"));
const CreateExperimentPage = lazy(() =>
  import("./pages/CreateExperimentPage").then((module) => ({ default: module.CreateExperimentPage })),
);
const PlatformDashboardPage = lazy(() =>
  import("./pages/PlatformDashboardPage").then((module) => ({ default: module.PlatformDashboardPage })),
);
const FeatureFlagsPage = lazy(() =>
  import("./pages/FeatureFlagsPage").then((module) => ({ default: module.FeatureFlagsPage })),
);
const AuditLogPage = lazy(() =>
  import("./pages/AuditLogPage").then((module) => ({ default: module.AuditLogPage })),
);
const MetricDefinitionsPage = lazy(() => import("./pages/MetricDefinitionsPage.tsx"));
const AdminSettingsPage = lazy(() =>
  import("./pages/AdminSettingsPage").then((module) => ({ default: module.AdminSettingsPage })),
);

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      retry: 2,
    },
  },
});

function ProtectedRoute() {
  const { isAuthenticated, isInitializing } = useAuth();
  const location = useLocation();

  if (isInitializing) {
    return <div className="min-h-screen flex items-center justify-center text-sm text-gray-500">Loading session...</div>;
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  }

  return <Outlet />;
}

function RouteFallback() {
  return <div className="min-h-screen flex items-center justify-center text-sm text-gray-500">Loading page...</div>;
}

/**
 * Wraps the routed content in a RouteErrorBoundary keyed by the current
 * pathname, so navigating to a different route always mounts a fresh
 * boundary — recovering automatically even if the user never clicks
 * "Try again" on the page that errored.
 */
function RouteErrorBoundaryHost({ children }: { children: ReactNode }) {
  const location = useLocation();

  return <RouteErrorBoundary key={location.pathname}>{children}</RouteErrorBoundary>;
}

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <WebSocketProvider>
          <TenantProvider>
            <BrowserRouter future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
              <RouteErrorBoundaryHost>
                <Suspense fallback={<RouteFallback />}>
                  <Routes>
                    <Route path="/login" element={<LoginPage />} />
                    <Route element={<ProtectedRoute />}>
                      <Route element={<Layout />}>
                        <Route path="/" element={<Navigate to="/dashboard" replace />} />
                        <Route path="/dashboard" element={<PlatformDashboardPage />} />
                        <Route path="/analytics" element={<Navigate to="/dashboard" replace />} />
                        <Route path="/experiments" element={<ExperimentListPage />} />
                        <Route path="/experiments/new" element={<CreateExperimentPage />} />
                        <Route path="/experiments/:id" element={<ExperimentDetailPage />} />
                        <Route path="/experiments/:id/timeline" element={<ExperimentTimelinePage />} />
                        <Route path="/flags" element={<FeatureFlagsPage />} />
                        <Route path="/metrics" element={<MetricDefinitionsPage />} />
                        <Route path="/audit-logs" element={<AuditLogPage />} />
                        <Route path="/settings" element={<AdminSettingsPage />} />
                      </Route>
                    </Route>
                  </Routes>
                </Suspense>
              </RouteErrorBoundaryHost>
            </BrowserRouter>
          </TenantProvider>
        </WebSocketProvider>
      </AuthProvider>
    </QueryClientProvider>
  );
}
