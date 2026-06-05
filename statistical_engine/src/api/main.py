"""FastAPI application entry point for the Statistical Engine."""
from __future__ import annotations

import logging
import os
import time

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware

from src.api.routes import analysis, bayesian, health, power

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="ExperimentHub Statistical Engine",
    version="1.0.0",
    description="Statistical analysis engine for A/B experiments",
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("CORS_ORIGINS", "*").split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def auth_middleware(request: Request, call_next):
    """Internal service-to-service auth via X-Internal-Key header."""
    # Health check bypasses auth
    if request.url.path.endswith("/health"):
        return await call_next(request)

    expected_key = os.getenv("INTERNAL_API_KEY", "dev-internal-key")
    provided_key = request.headers.get("x-internal-key", "")

    if provided_key != expected_key:
        from fastapi.responses import JSONResponse
        return JSONResponse(
            status_code=401,
            content={"error": "unauthorized", "message": "Invalid internal API key"},
        )

    return await call_next(request)


@app.middleware("http")
async def timing_middleware(request: Request, call_next):
    """Add server timing header."""
    start = time.perf_counter()
    response: Response = await call_next(request)
    elapsed_ms = (time.perf_counter() - start) * 1000
    response.headers["Server-Timing"] = f"total;dur={elapsed_ms:.1f}"
    return response


@app.middleware("http")
async def trace_context_middleware(request: Request, call_next):
    """W3C Trace Context propagation (Constitution Art.IX)."""
    traceparent = request.headers.get("traceparent", "")
    tracestate = request.headers.get("tracestate", "")

    if traceparent:
        logger.info(f"trace_id={traceparent}")

    response: Response = await call_next(request)

    if traceparent:
        response.headers["traceparent"] = traceparent
    if tracestate:
        response.headers["tracestate"] = tracestate

    return response


# Include routers
app.include_router(health.router, prefix="/stats/v1")
app.include_router(analysis.router, prefix="/stats/v1")
app.include_router(power.router, prefix="/stats/v1")
app.include_router(bayesian.router)
