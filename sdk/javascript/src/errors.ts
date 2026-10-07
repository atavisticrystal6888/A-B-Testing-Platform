export interface ErrorOptions {
  code?: string;
  status?: number;
  details?: unknown;
  cause?: unknown;
}

/** Base class for every error the SDK throws. Never thrown directly. */
export class ExperimentHubError extends Error {
  readonly code: string;
  readonly status?: number;
  readonly details?: unknown;

  constructor(message: string, options: ErrorOptions & { code: string }) {
    super(message, { cause: options.cause });
    this.name = new.target.name;
    this.code = options.code;
    this.status = options.status;
    this.details = options.details;
  }
}

/** Local pre-validation failure, or a server 400. */
export class ValidationError extends ExperimentHubError {
  constructor(message: string, options: ErrorOptions = {}) {
    super(message, { code: "validation_error", status: 400, ...options });
  }
}

/** Server 401: missing or invalid API key. */
export class AuthenticationError extends ExperimentHubError {
  constructor(message: string, options: ErrorOptions = {}) {
    super(message, { code: "unauthorized", status: 401, ...options });
  }
}

/** Server 404: unknown experiment or flag key. */
export class NotFoundError extends ExperimentHubError {
  constructor(message: string, options: ErrorOptions = {}) {
    super(message, { code: "not_found", status: 404, ...options });
  }
}

/** Server 429. `retryAfterMs` is derived from the `Retry-After` header when present. */
export class RateLimitError extends ExperimentHubError {
  readonly retryAfterMs?: number;
  readonly limit?: number;
  readonly remaining?: number;
  readonly resetAt?: number;

  constructor(
    message: string,
    options: ErrorOptions & {
      retryAfterMs?: number;
      limit?: number;
      remaining?: number;
      resetAt?: number;
    } = {},
  ) {
    const { retryAfterMs, limit, remaining, resetAt, ...rest } = options;
    super(message, { code: "rate_limited", status: 429, ...rest });
    this.retryAfterMs = retryAfterMs;
    this.limit = limit;
    this.remaining = remaining;
    this.resetAt = resetAt;
  }
}

/** Server 503: the platform could not enqueue the request (e.g. Kafka down). */
export class ServiceUnavailableError extends ExperimentHubError {
  constructor(message: string, options: ErrorOptions = {}) {
    super(message, { code: "service_unavailable", status: 503, ...options });
  }
}

/** `fetch` rejected, DNS failed, or the request timed out (`code: "timeout"`) or was aborted (`code: "aborted"`). */
export class NetworkError extends ExperimentHubError {
  constructor(message: string, options: ErrorOptions = {}) {
    super(message, { code: "network_error", ...options });
  }
}

/** Any other non-2xx response. `details` holds the raw body. */
export class ApiError extends ExperimentHubError {
  constructor(message: string, options: ErrorOptions = {}) {
    super(message, { code: "api_error", ...options });
  }
}

interface ErrorBody {
  error?: unknown;
  message?: unknown;
  details?: unknown;
}

function asErrorBody(body: unknown): ErrorBody {
  return typeof body === "object" && body !== null ? (body as ErrorBody) : {};
}

function numberHeader(headers: Headers, name: string): number | undefined {
  const raw = headers.get(name);
  if (raw === null) return undefined;
  const n = Number(raw);
  return Number.isFinite(n) ? n : undefined;
}

/** Build the right error subclass for a non-2xx response. */
export function errorFromResponse(
  method: string,
  path: string,
  status: number,
  headers: Headers,
  body: unknown,
): ExperimentHubError {
  const parsed = asErrorBody(body);
  const message =
    typeof parsed.message === "string" && parsed.message.length > 0
      ? parsed.message
      : `${method} ${path} failed with ${status}`;
  // Only override the subclass default code when the server actually sent one:
  // spreading `{ code: undefined }` would clobber the default.
  const serverCode = typeof parsed.error === "string" ? parsed.error : undefined;
  const common: ErrorOptions = serverCode ? { code: serverCode, details: parsed.details } : { details: parsed.details };

  switch (status) {
    case 400:
      return new ValidationError(message, common);
    case 401:
      return new AuthenticationError(message, common);
    case 404:
      return new NotFoundError(message, common);
    case 429: {
      const retryAfterSeconds = numberHeader(headers, "retry-after");
      return new RateLimitError(message, {
        ...common,
        retryAfterMs: retryAfterSeconds === undefined ? undefined : retryAfterSeconds * 1000,
        limit: numberHeader(headers, "x-ratelimit-limit"),
        remaining: numberHeader(headers, "x-ratelimit-remaining"),
        resetAt: numberHeader(headers, "x-ratelimit-reset"),
      });
    }
    case 503:
      return new ServiceUnavailableError(message, common);
    default:
      return new ApiError(message, { ...common, status, details: body });
  }
}
