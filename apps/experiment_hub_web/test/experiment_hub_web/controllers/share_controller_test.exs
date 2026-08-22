defmodule ExperimentHubWeb.ShareControllerTest do
  use ExperimentHubWeb.ConnCase, async: true

  alias ExperimentHub.Experiments
  alias ExperimentHub.Repo

  @salt "shared-readout"

  setup %{conn: conn} do
    tenant = tenant_fixture()
    api_key = api_key_fixture(tenant: tenant)

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-api-key", api_key.raw_key)

    Repo.put_tenant_id(tenant.id)

    %{conn: conn, tenant: tenant}
  end

  describe "POST /api/v1/experiments/:experiment_id/share-readout" do
    test "returns a url containing a signed token", %{conn: conn, tenant: tenant} do
      experiment = experiment_fixture(tenant: tenant)

      conn =
        post(conn, "/api/v1/experiments/#{experiment.id}/share-readout", %{
          "html" => "<html><body>readout</body></html>"
        })

      response = json_response(conn, 201)
      url = response["data"]["url"]

      assert is_binary(url)
      assert url =~ "/share/readout/"

      token = url |> String.split("/share/readout/") |> List.last()
      assert {:ok, _id} = Phoenix.Token.verify(ExperimentHubWeb.Endpoint, @salt, token)
    end

    test "404s when the experiment belongs to a different tenant", %{conn: conn} do
      other_tenant = tenant_fixture()
      other_experiment = experiment_fixture(tenant: other_tenant)

      conn =
        post(conn, "/api/v1/experiments/#{other_experiment.id}/share-readout", %{
          "html" => "<html><body>readout</body></html>"
        })

      response = json_response(conn, 404)
      assert response["error"] == "not_found"
    end

    test "422s when the html exceeds the 2MB cap", %{conn: conn, tenant: tenant} do
      experiment = experiment_fixture(tenant: tenant)
      oversized_html = String.duplicate("a", 2_000_001)

      conn =
        post(conn, "/api/v1/experiments/#{experiment.id}/share-readout", %{
          "html" => oversized_html
        })

      response = json_response(conn, 422)
      assert response["error"] == "validation_error"
      assert response["errors"]["html"]
    end
  end

  describe "GET /share/readout/:token" do
    test "serves the stored html with text/html when the token is valid", %{
      tenant: tenant
    } do
      experiment = experiment_fixture(tenant: tenant)

      {:ok, shared_readout} =
        Experiments.create_shared_readout(%{
          "tenant_id" => tenant.id,
          "experiment_id" => experiment.id,
          "html" => "<html><body>hello readout</body></html>"
        })

      token = Phoenix.Token.sign(ExperimentHubWeb.Endpoint, @salt, shared_readout.id)

      # The public route runs with no tenant context, and possibly a
      # completely unrelated one left behind on a reused process — prove the
      # lookup doesn't depend on tenant context matching at all.
      other_tenant = tenant_fixture()
      Repo.put_tenant_id(other_tenant.id)

      conn =
        Phoenix.ConnTest.build_conn()
        |> get("/share/readout/#{token}")

      assert conn.status == 200
      assert conn.resp_body == "<html><body>hello readout</body></html>"
      assert get_resp_header(conn, "content-type") |> Enum.at(0) =~ "text/html"
      assert get_resp_header(conn, "x-robots-tag") == ["noindex"]

      assert get_resp_header(conn, "content-security-policy") == [
               "default-src 'none'; style-src 'unsafe-inline'"
             ]
    end

    test "404s for a tampered token", %{tenant: tenant} do
      experiment = experiment_fixture(tenant: tenant)

      {:ok, shared_readout} =
        Experiments.create_shared_readout(%{
          "tenant_id" => tenant.id,
          "experiment_id" => experiment.id,
          "html" => "<html><body>hello readout</body></html>"
        })

      token = Phoenix.Token.sign(ExperimentHubWeb.Endpoint, @salt, shared_readout.id)
      tampered_token = token <> "tampered"

      Repo.clear_tenant_id()

      conn =
        Phoenix.ConnTest.build_conn()
        |> get("/share/readout/#{tampered_token}")

      response = json_response(conn, 404)
      assert response["error"] == "not_found"
    end

    test "404s for an expired token", %{tenant: tenant} do
      experiment = experiment_fixture(tenant: tenant)

      {:ok, shared_readout} =
        Experiments.create_shared_readout(%{
          "tenant_id" => tenant.id,
          "experiment_id" => experiment.id,
          "html" => "<html><body>hello readout</body></html>"
        })

      expired_token =
        Phoenix.Token.sign(ExperimentHubWeb.Endpoint, @salt, shared_readout.id,
          signed_at: System.system_time(:second) - 31 * 24 * 3600
        )

      Repo.clear_tenant_id()

      conn =
        Phoenix.ConnTest.build_conn()
        |> get("/share/readout/#{expired_token}")

      response = json_response(conn, 404)
      assert response["error"] == "not_found"
    end

    test "404s when the token is valid but the row no longer exists", %{
      tenant: tenant
    } do
      experiment = experiment_fixture(tenant: tenant)

      {:ok, shared_readout} =
        Experiments.create_shared_readout(%{
          "tenant_id" => tenant.id,
          "experiment_id" => experiment.id,
          "html" => "<html><body>hello readout</body></html>"
        })

      token = Phoenix.Token.sign(ExperimentHubWeb.Endpoint, @salt, shared_readout.id)

      Repo.delete!(shared_readout)
      Repo.clear_tenant_id()

      conn =
        Phoenix.ConnTest.build_conn()
        |> get("/share/readout/#{token}")

      response = json_response(conn, 404)
      assert response["error"] == "not_found"
    end
  end
end
