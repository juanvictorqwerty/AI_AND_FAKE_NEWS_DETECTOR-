# syntax=docker/dockerfile:1

ARG PYTHON_VERSION=3.12.13
FROM python:${PYTHON_VERSION}-slim as base

# Prevents Python from writing pyc files.
ENV PYTHONDONTWRITEBYTECODE=1

# Keeps Python from buffering stdout and stderr
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Create a non-privileged user that the app will run under.
ARG UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    appuser

# --- FIX 1: Set up writeable directories inside /tmp ---
# Hugging face will use HF_HOME, and Loguru can use /tmp/logs if needed
ENV HOME=/tmp
ENV HF_HOME=/tmp/hf_cache

# Create them explicitly and grant full permissions so appuser can read/write
RUN mkdir -p /tmp/hf_cache /tmp/logs && chmod -R 777 /tmp

# --- FIX 2: Ensure /app/logs is fully accessible if used ---
RUN mkdir -p /app/logs && chown -R appuser:appuser /app && chmod -R 777 /app/logs
# --------------------------------------------------------

# Download dependencies as a separate step to take advantage of Docker's caching.
RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=bind,source=requirements.txt,target=requirements.txt \
    python -m pip install -r requirements.txt

# Switch to the non-privileged user to run the application.
USER appuser

# Copy the source code into the container.
COPY --chown=appuser:appuser . .

# Expose the port that the application listens on.
EXPOSE 7860

# Run the application.
CMD APP_ENV=production gunicorn main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:7860 --log-level info