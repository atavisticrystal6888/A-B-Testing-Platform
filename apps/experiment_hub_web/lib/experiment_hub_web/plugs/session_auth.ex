defmodule ExperimentHubWeb.Plugs.SessionAuth do
  @moduledoc """
  JWT session authentication for dashboard login.
  Validates the `Authorization: Bearer <token>` header.
  Sets `current_user`, `tenant_id`, and `auth_method` in conn.assigns.
  """

  import Plug.Conn

  @secret_key_base_env "JWT_SECRET"

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- verify_token(token) do
      current_scope = %{
        tenant_id: claims["tenant_id"],
        user_id: claims["sub"],
        role: claims["role"]
      }

      conn
      |> assign(:current_user_id, claims["sub"])
      |> assign(:tenant_id, claims["tenant_id"])
      |> assign(:user_role, claims["role"])
      |> assign(:current_scope, current_scope)
      |> assign(:auth_method, :jwt)
    else
      _ -> conn
    end
  end

  @doc """
  Generates a JWT token for a user. Used during login.
  """
  def generate_token(user) do
    now = System.os_time(:second)

    claims = %{
      "sub" => user.id,
      "tenant_id" => user.tenant_id,
      "role" => user.role,
      "iat" => now,
      "exp" => now + 86_400
    }

    secret = get_secret()
    header = Base.url_encode64(Jason.encode!(%{"alg" => "HS256", "typ" => "JWT"}), padding: false)
    payload = Base.url_encode64(Jason.encode!(claims), padding: false)

    signature =
      :crypto.mac(:hmac, :sha256, secret, "#{header}.#{payload}")
      |> Base.url_encode64(padding: false)

    "#{header}.#{payload}.#{signature}"
  end

  def verify_token(token) do
    with [header_b64, payload_b64, signature_b64] <- String.split(token, "."),
         {:ok, _header} <- decode_json(header_b64),
         {:ok, claims} <- decode_json(payload_b64),
         true <- verify_signature(header_b64, payload_b64, signature_b64),
         true <- not_expired?(claims) do
      {:ok, claims}
    else
      _ -> {:error, :invalid_token}
    end
  end

  defp verify_signature(header_b64, payload_b64, signature_b64) do
    secret = get_secret()

    expected =
      :crypto.mac(:hmac, :sha256, secret, "#{header_b64}.#{payload_b64}")
      |> Base.url_encode64(padding: false)

    Plug.Crypto.secure_compare(expected, signature_b64)
  end

  defp not_expired?(%{"exp" => exp}) do
    System.os_time(:second) < exp
  end

  defp not_expired?(_), do: false

  defp decode_json(base64_str) do
    with {:ok, json} <- Base.url_decode64(base64_str, padding: false),
         {:ok, data} <- Jason.decode(json) do
      {:ok, data}
    end
  end

  defp get_secret do
    System.get_env(@secret_key_base_env) ||
      Application.get_env(:experiment_hub_web, :jwt_secret) ||
      raise "JWT_SECRET environment variable or :jwt_secret config is required"
  end
end
