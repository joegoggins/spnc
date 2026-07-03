# Collabornet REST API — FastAPI served by uvicorn.
#
# Pure-Python app, so buildx builds linux/amd64 + linux/arm64 (arm64 also covers
# Apple Silicon for local Docker/Kind). QEMU handles the non-native arch during
# the wheel install; that's cheap here since the deps ship prebuilt wheels.
# See .github/workflows/app-api.yml.
FROM python:3.12-slim

# Links this GHCR package to the repo (so Actions' GITHUB_TOKEN can push to it).
LABEL org.opencontainers.image.source="https://github.com/joegoggins/spnc"

# uv: fast, reproducible installs. Pinned copy lifted from the official image.
COPY --from=ghcr.io/astral-sh/uv:0.11 /uv /bin/uv

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_NO_CACHE=1

WORKDIR /app

# Install the package (+ its deps) into the system environment — no venv needed
# in a container; the image IS the environment. pyproject + source are all
# hatchling needs to build the wheel.
COPY pyproject.toml ./
COPY app_api ./app_api
RUN uv pip install --system .

EXPOSE 80
# Bind all interfaces on the Service port. Single worker is plenty for now.
CMD ["uvicorn", "app_api.main:app", "--host", "0.0.0.0", "--port", "80"]
