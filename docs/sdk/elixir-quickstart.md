# Elixir SDK Quickstart

## Installation

Add `experiment_hub_sdk` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:experiment_hub_sdk, "~> 0.1.0"}
  ]
end
```

## Configuration

```elixir
# config/config.exs
config :experiment_hub_sdk,
  base_url: "https://your-instance.example.com",
  api_key: System.get_env("EXPERIMENT_HUB_API_KEY"),
  tenant_id: System.get_env("EXPERIMENT_HUB_TENANT_ID")
```

## Usage

### Get a Variant Assignment

```elixir
case ExperimentHubSDK.assign("checkout-button-color", user_id: user.id) do
  {:ok, %{variant_id: "blue"}} ->
    render_blue_button()

  {:ok, %{variant_id: "green"}} ->
    render_green_button()

  {:ok, %{variant_id: "control"}} ->
    render_default_button()

  {:error, reason} ->
    Logger.warning("Assignment failed: #{inspect(reason)}, using control")
    render_default_button()
end
```

### Track Events

```elixir
ExperimentHubSDK.track("purchase", %{
  experiment_id: "checkout-button-color",
  user_id: user.id,
  variant_id: assigned_variant,
  properties: %{
    value: order.total,
    currency: "USD"
  }
})
```

### Batch Events

```elixir
events = [
  %{event_type: "page_view", user_id: "u1", experiment_id: "exp-1", variant_id: "v1"},
  %{event_type: "click", user_id: "u2", experiment_id: "exp-1", variant_id: "v2"}
]

ExperimentHubSDK.track_batch(events)
```

### Feature Flags

```elixir
if ExperimentHubSDK.flag_enabled?("dark-mode", user_id: user.id) do
  render_dark_theme()
else
  render_light_theme()
end
```

### Check Experiment Results

```elixir
{:ok, results} = ExperimentHubSDK.get_results("checkout-button-color")

for variant <- results.variants do
  IO.puts("#{variant.variant_id}: #{variant.conversion_rate} (p=#{variant.p_value})")
end
```

## Error Handling

The SDK returns `{:ok, result}` or `{:error, reason}` tuples. Common errors:

| Error | Description |
|-------|-------------|
| `:unauthorized` | Invalid API key |
| `:not_found` | Experiment or flag not found |
| `:rate_limited` | Too many requests |
| `:timeout` | Request timed out |

## Graceful Degradation

The SDK defaults to control variant when the service is unreachable:

```elixir
config :experiment_hub_sdk,
  fallback_variant: "control",
  timeout: 500,         # ms
  retry_count: 1
```
