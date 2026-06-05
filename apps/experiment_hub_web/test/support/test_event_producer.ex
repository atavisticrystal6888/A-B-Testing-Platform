defmodule ExperimentHubWeb.TestEventProducer do
  def produce(_topic, _key, _value) do
    Application.get_env(:experiment_hub_web, :test_event_producer_result, :ok)
  end
end
