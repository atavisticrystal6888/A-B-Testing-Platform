"""Pydantic models for power/sample-size calculation endpoint."""
from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, Field


class PowerRequest(BaseModel):
    baseline_rate: float = Field(..., gt=0, lt=1, description="Expected baseline conversion rate")
    minimum_detectable_effect: float = Field(..., gt=0, description="MDE as absolute difference")
    significance_level: float = Field(default=0.05, gt=0, lt=1)
    power: float = Field(default=0.80, gt=0, lt=1)
    num_variants: int = Field(default=2, ge=2, le=10)
    correction_method: Optional[str] = None


class PowerResponse(BaseModel):
    sample_size_per_variant: int
    total_sample_size: int
    baseline_rate: float
    minimum_detectable_effect: float
    significance_level: float
    power: float
    num_variants: int
    correction_method: Optional[str] = None
