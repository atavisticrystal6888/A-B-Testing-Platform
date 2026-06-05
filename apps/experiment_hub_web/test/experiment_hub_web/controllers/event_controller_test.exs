defmodule ExperimentHubWeb.EventControllerTest do
  use ExperimentHubWeb.ConnCase, async: false

  setup %{conn: conn} do
    tenant = tenant_fixture()
    api_key = api_key_fixture(%{tenant: tenant})

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("x-api-key", api_key.raw_key)

    {:ok, conn: conn, tenant: tenant}
  end

  describe "POST /v1/events" do
    test "accepts valid event", %{conn: conn} do
      conn =
        post(conn, "/v1/events", %{
          "experiment_id" => Ecto.UUID.generate(),
          "user_id" => "user-1",
          "event_type" => "conversion",
          "event_name" => "checkout_completed",
          "value" => 1,
          "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "idempotency_key" => "evt_#{System.unique_integer([:positive])}"
        })

      assert %{"status" => "accepted"} = json_response(conn, 202)
    end

    test "rejects event missing required fields", %{conn: conn} do
      conn = post(conn, "/v1/events", %{})
      assert %{"error" => "validation_error"} = json_response(conn, 400)
    end

    test "rejects invalid event_type", %{conn: conn} do
      conn =
        post(conn, "/v1/events", %{
          "experiment_id" => Ecto.UUID.generate(),
          "user_id" => "user-1",
          "event_type" => "invalid_type",
          "event_name" => "test",
          "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "idempotency_key" => "key-1"
        })

      assert %{"error" => "validation_error"} = json_response(conn, 400)
    end
  end

  describe "POST /v1/events/batch" do
    test "accepts batch of valid events", %{conn: conn} do
      events = [
        %{
          "experiment_id" => Ecto.UUID.generate(),
          "user_id" => "user-1",
          "event_type" => "conversion",
          "event_name" => "checkout",
          "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "idempotency_key" => "batch-1-#{System.unique_integer([:positive])}"
        },
        %{
          "experiment_id" => Ecto.UUID.generate(),
          "user_id" => "user-2",
          "event_type" => "metric",
          "event_name" => "page_load_time",
          "value" => 1.234,
          "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "idempotency_key" => "batch-2-#{System.unique_integer([:positive])}"
        }
      ]

      conn = post(conn, "/v1/events/batch", %{"events" => events})

      assert %{"status" => "accepted", "accepted" => 2, "rejected" => 0} =
               json_response(conn, 202)
    end

    test "returns 207 for partial success", %{conn: conn} do
      events = [
        %{
          "experiment_id" => Ecto.UUID.generate(),
          "user_id" => "user-1",
          "event_type" => "conversion",
          "event_name" => "checkout",
          "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "idempotency_key" => "partial-1-#{System.unique_integer([:positive])}"
        },
        %{
          # Missing required fields
          "event_type" => "invalid"
        }
      ]

      conn = post(conn, "/v1/events/batch", %{"events" => events})
      response = json_response(conn, 207)
      assert response["status"] == "partial"
      assert response["accepted"] == 1
      assert response["rejected"] == 1
    end

    test "rejects missing events field", %{conn: conn} do
      conn = post(conn, "/v1/events/batch", %{})
      assert %{"error" => "validation_error"} = json_response(conn, 400)
    end
  end
end
