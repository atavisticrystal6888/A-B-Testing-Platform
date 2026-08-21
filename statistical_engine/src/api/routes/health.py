"""Health check endpoint."""
from fastapi import APIRouter

router = APIRouter()


@router.get("/health")
async def health_check() -> dict[str, str]:
    """GET /stats/v1/health"""
    return {"status": "ok", "service": "statistical-engine", "version": "1.0.0"}
