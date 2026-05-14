# ------------------------------------------------------------
# Dockerfile for LLM RAG Project
# Python 3.12 for stability with ML libraries
# ------------------------------------------------------------
FROM python:3.12-slim

# Prevent Python from writing .pyc files & enable real-time logs
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# System dependencies needed by ML libs
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------
# FIX 1: Set WORKDIR once to /app/backend
# ------------------------------------------
WORKDIR /app/backend

# ------------------------------------------
# FIX 2: pip root warning suppressed
# ------------------------------------------
COPY backend/requirements.txt .
RUN pip install --upgrade pip --root-user-action=ignore && \
    pip install -r requirements.txt --root-user-action=ignore

# Copy backend application code into /app/backend
COPY backend/ .

# ------------------------------------------
# FIX 3: uploads folder inside /app/backend
# matches os.path.dirname(__file__) in main.py
# which resolves to /app/backend/uploads
# ------------------------------------------
RUN mkdir -p /app/backend/uploads

# Non-root user for security
RUN useradd -m -u 1001 appuser && \
    chown -R appuser:appuser /app
USER appuser

# Expose FastAPI port
EXPOSE 8000

# Health check — confirms app is truly running
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Start FastAPI server
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--log-level", "info"]
