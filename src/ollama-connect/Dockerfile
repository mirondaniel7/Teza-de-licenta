# ---- 1️⃣ Builder stage ----
FROM python:3.11-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy dependency file first (caching)
COPY requirements.txt .

# Install dependencies into separate folder
RUN pip install --upgrade pip && \
    pip install --prefix=/install --no-cache-dir -r requirements.txt

# ---- 2️⃣ Runtime stage ----
FROM python:3.11-slim

RUN useradd --create-home appuser

WORKDIR /app

# Copy installed dependencies from builder
COPY --from=builder /install /usr/local

# Copy only app files
COPY app.py .

# Drop privileges
USER appuser

# Expose API port
EXPOSE 8000

# Healthcheck (optional)
HEALTHCHECK CMD curl --fail http://localhost:8000/health || exit 1

# Start FastAPI server
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]