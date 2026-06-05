defmodule ExperimentHubWeb.FallbackController do
  use ExperimentHubWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(422)
    |> json(%{
      error: "validation_error",
      errors:
        Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
          Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
            opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
          end)
        end)
    })
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(404)
    |> json(%{error: "not_found", message: "Resource not found"})
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(401)
    |> json(%{error: "unauthorized", message: "Unauthorized"})
  end
end
