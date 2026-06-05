defmodule ExperimentHubWeb.Router do
  use ExperimentHubWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug ExperimentHubWeb.Plugs.TraceContext
  end

  pipeline :api_authenticated do
    plug ExperimentHubWeb.Plugs.ApiKeyAuth
    plug ExperimentHubWeb.Plugs.SessionAuth
    plug ExperimentHubWeb.Plugs.RequireAuth
    plug ExperimentHubWeb.Plugs.TenantContext
    plug ExperimentHubWeb.Plugs.RateLimiter
  end

  pipeline :require_editor do
    plug ExperimentHubWeb.Plugs.Authorize, roles: [:editor, :admin]
  end

  pipeline :require_admin do
    plug ExperimentHubWeb.Plugs.Authorize, roles: [:admin]
  end

  # Public endpoints (no auth required)
  scope "/", ExperimentHubWeb do
    pipe_through :api

    get "/health", HealthController, :index
  end

  # Auth endpoints (public)
  scope "/api/v1/auth", ExperimentHubWeb do
    pipe_through :api

    post "/login", AuthController, :login
    post "/logout", AuthController, :logout
  end

  # Authenticated API endpoints
  scope "/api/v1", ExperimentHubWeb do
    pipe_through [:api, :api_authenticated]

    # Auth
    get "/auth/me", AuthController, :me

    # Viewer+ endpoints (read-only)
    get "/experiments", ExperimentController, :index
    get "/experiments/:id", ExperimentController, :show
    get "/experiments/:experiment_id/results", ResultsController, :show
    get "/metric-definitions", MetricDefinitionController, :index
    get "/metric-definitions/:id", MetricDefinitionController, :show
    get "/experiment-groups", ExperimentGroupController, :index
    get "/experiment-groups/:id", ExperimentGroupController, :show
    get "/experiments/:experiment_id/metrics", ExperimentMetricController, :index

    # Feature flags
    get "/flags", FeatureFlagController, :index
    get "/flags/:id", FeatureFlagController, :show
    post "/flags/evaluate", FeatureFlagController, :evaluate
    post "/flags/evaluate/batch", FeatureFlagController, :evaluate_batch

    # Audit logs
    get "/experiments/:experiment_id/audit-logs", AuditLogController, :index
    get "/audit-logs", AuditLogController, :tenant_index

    # Analytics
    get "/analytics/overview", AnalyticsController, :overview

    # Export
    get "/experiments/:experiment_id/export", ExportController, :export_experiment
    get "/experiments/:experiment_id/export/results", ExportController, :export_results

    # Tenant
    get "/tenant", TenantController, :show
    get "/tenant/settings", TenantController, :settings

    # GDPR
    get "/gdpr/export", GDPRController, :export
    get "/gdpr/export/:user_id", GDPRController, :export
  end

  # Assignment endpoints (API key authenticated, any role)
  scope "/v1", ExperimentHubWeb do
    pipe_through [:api, :api_authenticated]

    post "/assign", AssignController, :assign
    post "/assign/batch", AssignController, :batch_assign

    post "/events", EventController, :create
    post "/events/batch", EventController, :batch_create
  end

  # Editor+ endpoints (create/update)
  scope "/api/v1", ExperimentHubWeb do
    pipe_through [:api, :api_authenticated, :require_editor]

    post "/experiments", ExperimentController, :create
    put "/experiments/:id", ExperimentController, :update
    post "/experiments/:id/start", ExperimentController, :start
    post "/experiments/:id/pause", ExperimentController, :pause
    post "/experiments/:id/resume", ExperimentController, :resume
    post "/experiments/:id/conclude", ExperimentController, :conclude
    post "/experiments/:experiment_id/analyze", ResultsController, :analyze

    post "/metric-definitions", MetricDefinitionController, :create
    put "/metric-definitions/:id", MetricDefinitionController, :update

    post "/experiments/:experiment_id/metrics", ExperimentMetricController, :create
    delete "/experiments/:experiment_id/metrics/:id", ExperimentMetricController, :delete

    # Feature flags management
    post "/flags", FeatureFlagController, :create
    put "/flags/:id", FeatureFlagController, :update

    # Tenant settings
    put "/tenant", TenantController, :update
    put "/tenant/settings", TenantController, :update_settings
  end

  # Admin-only endpoints
  scope "/api/v1", ExperimentHubWeb do
    pipe_through [:api, :api_authenticated, :require_admin]

    delete "/metric-definitions/:id", MetricDefinitionController, :delete
    delete "/flags/:id", FeatureFlagController, :delete

    # GDPR admin operations
    post "/gdpr/anonymize", GDPRController, :erase
    post "/gdpr/erase/:user_id", GDPRController, :erase
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:experiment_hub_web, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: ExperimentHubWeb.Telemetry
    end
  end
end
