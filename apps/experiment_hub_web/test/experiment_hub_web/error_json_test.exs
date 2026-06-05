defmodule ExperimentHubWeb.ErrorJSONTest do
  use ExperimentHubWeb.ConnCase, async: true

  test "renders 404" do
    assert ExperimentHubWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert ExperimentHubWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
