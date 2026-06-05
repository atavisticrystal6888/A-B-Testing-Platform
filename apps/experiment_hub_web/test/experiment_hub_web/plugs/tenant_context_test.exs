defmodule ExperimentHubWeb.Plugs.TenantContextTest do
  use ExperimentHubWeb.ConnCase, async: true

  alias ExperimentHubWeb.Plugs.TenantContext

  describe "call/2" do
    test "sets tenant context when tenant_id is assigned", %{conn: conn} do
      tenant = tenant_fixture()

      conn =
        conn
        |> assign(:tenant_id, tenant.id)
        |> TenantContext.call(TenantContext.init([]))

      refute conn.halted
    end

    test "returns 401 when tenant_id is missing", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> TenantContext.call(TenantContext.init([]))

      assert conn.halted
      assert conn.status == 401
    end
  end
end
