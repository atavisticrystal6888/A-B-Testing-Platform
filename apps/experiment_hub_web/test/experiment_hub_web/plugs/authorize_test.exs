defmodule ExperimentHubWeb.Plugs.AuthorizeTest do
  use ExperimentHubWeb.ConnCase, async: true

  alias ExperimentHubWeb.Plugs.Authorize

  describe "call/2" do
    test "allows when user role matches required role", %{conn: conn} do
      conn =
        conn
        |> assign(:user_role, "admin")
        |> Authorize.call(Authorize.init(roles: [:admin]))

      refute conn.halted
    end

    test "allows editor when editor or admin required", %{conn: conn} do
      conn =
        conn
        |> assign(:user_role, "editor")
        |> Authorize.call(Authorize.init(roles: [:editor, :admin]))

      refute conn.halted
    end

    test "denies viewer when editor role required", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> assign(:user_role, "viewer")
        |> Authorize.call(Authorize.init(roles: [:editor, :admin]))

      assert conn.halted
      assert conn.status == 403
    end

    test "denies when no role is set", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> Authorize.call(Authorize.init(roles: [:viewer, :editor, :admin]))

      assert conn.halted
      assert conn.status == 403
    end

    test "API key auth defaults to admin role", %{conn: conn} do
      conn =
        conn
        |> assign(:api_key, %{id: "test"})
        |> Authorize.call(Authorize.init(roles: [:admin]))

      refute conn.halted
    end

    test "viewer role can access viewer-level routes", %{conn: conn} do
      conn =
        conn
        |> assign(:user_role, "viewer")
        |> Authorize.call(Authorize.init(roles: [:viewer, :editor, :admin]))

      refute conn.halted
    end
  end
end
