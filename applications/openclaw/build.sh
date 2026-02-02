#!/bin/bash
set -euo pipefail

OPENCLAW_VERSION="2026.2.1"
OPENCLAW_REPO="https://github.com/openclaw/openclaw.git"
BUILD_DIR="/tmp/openclaw-build"
TARGET_HOST="k3s-worker-01"

echo "=== OpenClaw ${OPENCLAW_VERSION} Build ==="

# Clone source at version tag
rm -rf "${BUILD_DIR}"
git clone --depth 1 --branch "v${OPENCLAW_VERSION}" "${OPENCLAW_REPO}" "${BUILD_DIR}"
cd "${BUILD_DIR}"

# Build main image (official Dockerfile)
echo "Building openclaw:${OPENCLAW_VERSION}..."
docker build -t "openclaw:${OPENCLAW_VERSION}" .

# Build browser sandbox (official Dockerfile.sandbox-browser)
echo "Building openclaw-sandbox-browser:bookworm-slim..."
docker build -t "openclaw-sandbox-browser:bookworm-slim" -f Dockerfile.sandbox-browser .

# Transfer to k3s-worker-01
echo "Transferring images to ${TARGET_HOST}..."
docker save "openclaw:${OPENCLAW_VERSION}" | \
  ssh "${TARGET_HOST}" 'sudo ctr -n k8s.io images import -'
docker save "openclaw-sandbox-browser:bookworm-slim" | \
  ssh "${TARGET_HOST}" 'sudo ctr -n k8s.io images import -'

# Cleanup
rm -rf "${BUILD_DIR}"

echo "Build complete!"
echo "  Main:    openclaw:${OPENCLAW_VERSION}"
echo "  Browser: openclaw-sandbox-browser:bookworm-slim"
