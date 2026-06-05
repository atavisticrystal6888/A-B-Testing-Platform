defmodule ExperimentHubWeb.Controllers.GdprControllerTest do
  use ExperimentHubWeb.ConnCase, async: true

  describe "POST /api/v1/gdpr/anonymize" do
    test "requires authentication", %{conn: conn} do
      conn = post(conn, "/api/v1/gdpr/anonymize", %{user_id: "user-123"})
      assert json_response(conn, 401)
    end
  end

  describe "GET /api/v1/gdpr/export" do
    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/v1/gdpr/export", %{user_id: "user-123"})
      assert json_response(conn, 401)
    end
  end
end
