[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ApiKey,

    [string]$BaseUrl = "http://127.0.0.1:4000",
    [string]$Tenant = "local-dev",
    [string]$Email = "admin@local.dev",
    [string]$Password = "ValidP@ssword123"
)

$ErrorActionPreference = "Stop"
$timestamp = [DateTime]::UtcNow.ToString("o")
$experimentKey = "manual-e2e-demo-$(Get-Date -Format 'yyyyMMddHHmmss')"

$login = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/v1/auth/login" -ContentType "application/json" -Body (
    @{
        tenant_id = $Tenant
        email     = $Email
        password  = $Password
    } | ConvertTo-Json
)

$jwtHeaders = @{ Authorization = "Bearer $($login.access_token)" }
$sdkHeaders = @{ "X-API-Key" = $ApiKey }

$metrics = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/v1/metric-definitions" -Headers $jwtHeaders
$primaryMetric = $metrics.data | Where-Object { $_.key -eq "checkout_conversion" } | Select-Object -First 1

if ($null -eq $primaryMetric) {
    throw "The checkout_conversion metric is missing. Run 'mix dev.demo' before this script."
}

$experiment = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/v1/experiments" -Headers $jwtHeaders -ContentType "application/json" -Body (
    @{
        key         = $experimentKey
        name        = "Manual E2E Lifecycle Demo"
        hypothesis  = "A concise value proposition increases completed checkout conversions."
        description = "Created by scripts/demo-e2e.ps1."
        feature_tag = "e2e-demo"
        variants    = @(
            @{
                key                = "control"
                name               = "Current Experience"
                is_control         = $true
                traffic_allocation = 5000
                sort_order         = 0
            },
            @{
                key                = "value-proposition"
                name               = "Value Proposition"
                is_control         = $false
                traffic_allocation = 5000
                sort_order         = 1
            }
        )
    } | ConvertTo-Json -Depth 6
)

Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/v1/experiments/$($experiment.id)/metrics" -Headers $jwtHeaders -ContentType "application/json" -Body (
    @{
        metric_definition_id = $primaryMetric.id
        role                 = "primary"
    } | ConvertTo-Json
) | Out-Null

$started = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/v1/experiments/$($experiment.id)/start" -Headers $jwtHeaders -ContentType "application/json" -Body "{}"

$assignment = Invoke-RestMethod -Method Post -Uri "$BaseUrl/v1/assign" -Headers $sdkHeaders -ContentType "application/json" -Body (
    @{
        experiment_key = $experimentKey
        user_id        = "manual-e2e-user-001"
        attributes     = @{ country = "US"; plan = "pro" }
    } | ConvertTo-Json -Depth 4
)

$events = Invoke-RestMethod -Method Post -Uri "$BaseUrl/v1/events/batch" -Headers $sdkHeaders -ContentType "application/json" -Body (
    @{
        events = @(
            @{
                experiment_id   = $experiment.id
                user_id         = "manual-e2e-user-001"
                event_type      = "conversion"
                event_name      = "checkout_completed"
                idempotency_key = "$experimentKey-conversion"
                timestamp       = $timestamp
            },
            @{
                experiment_id   = $experiment.id
                user_id         = "manual-e2e-user-001"
                event_type      = "revenue"
                event_name      = "order_completed"
                value           = 129.99
                idempotency_key = "$experimentKey-revenue"
                timestamp       = $timestamp
            }
        )
    } | ConvertTo-Json -Depth 6
)

$analysis = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/v1/experiments/$($experiment.id)/analyze" -Headers $jwtHeaders -ContentType "application/json" -Body "{}"
$results = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/v1/experiments/$($experiment.id)/results" -Headers $jwtHeaders

$paused = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/v1/experiments/$($experiment.id)/pause" -Headers $jwtHeaders -ContentType "application/json" -Body "{}"
$resumed = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/v1/experiments/$($experiment.id)/resume" -Headers $jwtHeaders -ContentType "application/json" -Body "{}"
$winner = $experiment.variants | Where-Object { -not $_.is_control } | Select-Object -First 1

$concluded = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/v1/experiments/$($experiment.id)/conclude" -Headers $jwtHeaders -ContentType "application/json" -Body (
    @{
        decision          = "ship_variant"
        rationale         = "Manual end-to-end demo completed successfully."
        winner_variant_id = $winner.id
    } | ConvertTo-Json
)

[pscustomobject]@{
    experiment_key        = $experimentKey
    experiment_id         = $experiment.id
    started_status        = $started.status
    assigned_variant      = $assignment.variant_key
    event_batch_status    = $events.status
    accepted_events       = $events.accepted
    analysis_status       = $analysis.status
    results_status        = $results.overall_status
    results_metric_count  = $results.metrics.Count
    paused_status         = $paused.status
    resumed_status        = $resumed.status
    concluded_status      = $concluded.status
} | ConvertTo-Json