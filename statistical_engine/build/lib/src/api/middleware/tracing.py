"""W3C Trace Context middleware for FastAPI (Constitution Art.IX)."""

import logging
import uuid

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

logger = logging.getLogger(__name__)


class TraceContextMiddleware(BaseHTTPMiddleware):
    """Extract/inject W3C Trace Context headers (traceparent/tracestate)."""

    async def dispatch(self, request: Request, call_next) -> Response:
        # Extract incoming trace context
        traceparent = request.headers.get("traceparent")
        tracestate = request.headers.get("tracestate", "")

        if traceparent:
            trace_id, parent_span_id = self._parse_traceparent(traceparent)
        else:
            trace_id = uuid.uuid4().hex
            parent_span_id = "0000000000000000"

        # Generate new span ID for this request
        span_id = uuid.uuid4().hex[:16]

        # Store in request state for access in route handlers
        request.state.trace_id = trace_id
        request.state.span_id = span_id
        request.state.parent_span_id = parent_span_id
        request.state.tracestate = tracestate

        # Log with trace context
        logger.info(
            "Request started",
            extra={
                "trace_id": trace_id,
                "span_id": span_id,
                "method": request.method,
                "path": request.url.path,
            },
        )

        response = await call_next(request)

        # Inject trace context into response headers
        response_traceparent = f"00-{trace_id}-{span_id}-01"
        response.headers["traceparent"] = response_traceparent
        if tracestate:
            response.headers["tracestate"] = tracestate

        return response

    @staticmethod
    def _parse_traceparent(traceparent: str) -> tuple[str, str]:
        """Parse W3C traceparent header: version-trace_id-parent_id-flags."""
        try:
            parts = traceparent.split("-")
            if len(parts) >= 3:
                return parts[1], parts[2]
        except (ValueError, IndexError):
            pass
        return uuid.uuid4().hex, "0000000000000000"
