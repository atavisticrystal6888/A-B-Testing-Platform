/** Typed API client with fetch wrapper, auth headers, and error handling */

function normalizeBaseUrl(url: string): string {
  return url.endsWith("/") ? url.slice(0, -1) : url;
}

export function getApiBaseUrl(): string {
  const configuredBaseUrl = import.meta.env.VITE_API_URL;

  if (configuredBaseUrl) {
    return normalizeBaseUrl(configuredBaseUrl);
  }

  if (typeof window !== "undefined") {
    return window.location.origin;
  }

  return "http://localhost:4000";
}

export function buildApiUrl(path: string): string {
  return new URL(path, `${getApiBaseUrl()}/`).toString();
}

export function getWebSocketUrl(): string {
  const url = new URL(`${getApiBaseUrl()}/`);

  url.protocol = url.protocol === "https:" ? "wss:" : "ws:";
  url.pathname = "/socket";
  url.search = "";
  url.hash = "";

  return url.toString();
}

class ApiError extends Error {
  constructor(
    public status: number,
    public body: unknown,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

function getAuthHeaders(): Record<string, string> {
  const token = localStorage.getItem("auth_token");
  const apiKey = localStorage.getItem("api_key");

  const headers: Record<string, string> = {
    "Content-Type": "application/json",
  };

  if (token) headers["Authorization"] = `Bearer ${token}`;
  if (apiKey) headers["X-API-Key"] = apiKey;

  return headers;
}

async function request<T>(
  method: string,
  path: string,
  body?: unknown,
): Promise<T> {
  const url = buildApiUrl(path);

  const response = await fetch(url, {
    method,
    headers: getAuthHeaders(),
    body: body ? JSON.stringify(body) : undefined,
  });

  if (!response.ok) {
    const errorBody = await response.json().catch(() => null);
    throw new ApiError(
      response.status,
      errorBody,
      `API error: ${response.status} ${response.statusText}`,
    );
  }

  if (response.status === 204) return {} as T;
  return response.json();
}

export const api = {
  get: <T>(path: string) => request<T>("GET", path),
  post: <T>(path: string, body?: unknown) => request<T>("POST", path, body),
  put: <T>(path: string, body?: unknown) => request<T>("PUT", path, body),
  delete: <T>(path: string) => request<T>("DELETE", path),
};

export { ApiError };
