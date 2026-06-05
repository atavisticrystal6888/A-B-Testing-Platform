# syntax=docker/dockerfile:1.7

FROM python:3.12-slim

ARG PIP_TRUSTED_HOST=

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY docker/certs/ /usr/local/share/ca-certificates/

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential ca-certificates && \
    update-ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY statistical_engine/pyproject.toml ./pyproject.toml
COPY statistical_engine/src ./src

RUN PIP_TRUSTED_HOST="${PIP_TRUSTED_HOST}" python -m pip install --upgrade pip && \
    PIP_TRUSTED_HOST="${PIP_TRUSTED_HOST}" python -m pip install --no-cache-dir .

EXPOSE 8000

CMD ["uvicorn", "src.api.main:app", "--host", "0.0.0.0", "--port", "8000"]