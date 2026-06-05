"""Power calculation route: POST /stats/v1/power."""
from fastapi import APIRouter

from src.core.power import sample_size_proportions
from src.models.power import PowerRequest, PowerResponse

router = APIRouter()


@router.post("/power", response_model=PowerResponse)
async def calculate_power(request: PowerRequest) -> PowerResponse:
    """POST /stats/v1/power - Calculate required sample size."""
    result = sample_size_proportions(
        baseline_rate=request.baseline_rate,
        minimum_detectable_effect=request.minimum_detectable_effect,
        significance_level=request.significance_level,
        power=request.power,
        num_variants=request.num_variants,
        correction_method=request.correction_method,
    )

    return PowerResponse(**result)
