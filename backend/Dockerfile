# syntax=docker/dockerfile:1
# ── Build stage ────────────────────────────────────────────────
# Use Python 3.10 (matches conda env in QUICKSTART.md)
FROM python:3.10-slim AS builder

# System deps needed by PaddleOCR / OpenCV / psycopg
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        libglib2.0-0 \
        libgl1 \
        libgomp1 \
        libsm6 \
        libxrender1 \
        libxext6 \
        curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade pip \
 && pip install -r requirements.txt

# ── Runtime stage ──────────────────────────────────────────────
FROM python:3.10-slim AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
        libglib2.0-0 \
        libgl1 \
        libgomp1 \
        libsm6 \
        libxrender1 \
        libxext6 \
        curl \
        postgresql-client \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy application code
COPY . .

# Copy & set the entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh



EXPOSE 8000

ENTRYPOINT ["/docker-entrypoint.sh"]
# Single worker: PaddleOCR is CPU-heavy; multiple forked workers race on model download
# and don't improve throughput for this workload.
CMD ["uvicorn", "app.api.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]