defmodule ExperimentHubWeb.AssignControllerTest do
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

  describe "POST /v1/assign" do
    test "returns 404 when experiment not found", %{conn: conn} do
      conn =
        post(conn, "/v1/assign", %{
          "user_id" => "user-1",
          "experiment_key" => "nonexistent-exp"
        })

      assert %{"error" => "experiment_not_found"} = json_response(conn, 404)
    end

    test "requires user_id and experiment_key", %{conn: conn} do
      conn = post(conn, "/v1/assign", %{})
      response = json_response(conn, 400)
      assert response["error"]
    end
  end

  describe "POST /v1/assign/batch" do
    test "returns assignments for multiple experiments", %{conn: conn} do
      conn =
        post(conn, "/v1/assign/batch", %{
          "user_id" => "user-1",
          "experiment_keys" => ["exp-1", "exp-2"]
        })

      assert %{"user_id" => "user-1", "assignments" => assignments} = json_response(conn, 200)
      assert is_list(assignments)
    end
  end
end
