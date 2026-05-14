# ------------------------------------------------------------
# Dockerfile for LLM RAG Project
# Python 3.12 for stability with ML libraries
# ------------------------------------------------------------
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app/backend

COPY backend/requirements.txt .

# --------------------------------------------------
# Install CPU only torch FIRST before requirements
# prevents sentence-transformers auto-pulling
# GPU torch which is 7GB and fills disk
# CPU torch = only 500MB
# --------------------------------------------------
RUN pip install --upgrade pip --root-user-action=ignore && \
    pip install torch --index-url https://download.pytorch.org/whl/cpu \
        --root-user-action=ignore && \
    pip install -r requirements.txt --root-user-action=ignore

COPY backend/ .

RUN mkdir -p /app/backend/uploads

RUN useradd -m -u 1001 appuser && \
    chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--log-level", "info"]
