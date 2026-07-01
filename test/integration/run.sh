#!/usr/bin/env bash
# test/integration/run.sh
#
# Host orchestrator for the dind integration test.
# Spins up an isolated Docker-in-Docker daemon, mounts the repo into it,
# runs the full backup → wipe → restore → verify cycle, then tears down.
#
# Usage:
#   bash test/integration/run.sh
#
# Requirements: docker must be running on the host (any version ≥ 20).
# Privileged containers must be allowed (needed for dind).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIND_NAME="dbk-dind-$$"
DIND_IMAGE="docker:28-dind"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

log()  { echo -e "${GREEN}[integration]${NC} $*"; }
warn() { echo -e "${YELLOW}[integration]${NC} $*"; }
die()  { echo -e "${RED}[integration] ERROR:${NC} $*" >&2; exit 1; }

# ── Cleanup ────────────────────────────────────────────────────────────────
cleanup() {
  local exit_code=$?
  if docker inspect "$DIND_NAME" >/dev/null 2>&1; then
    warn "Removing dind container $DIND_NAME ..."
    docker rm -f "$DIND_NAME" >/dev/null 2>&1 || true
  fi
  if [ $exit_code -ne 0 ]; then
    die "Integration tests FAILED (exit $exit_code)"
  fi
}
trap cleanup EXIT

# ── Pre-flight ─────────────────────────────────────────────────────────────
docker info >/dev/null 2>&1 || die "Docker is not running on the host."

# ── Start dind ────────────────────────────────────────────────────────────
log "Starting isolated Docker-in-Docker daemon ($DIND_NAME) ..."
docker run -d \
  --privileged \
  --name "$DIND_NAME" \
  -e DOCKER_TLS_CERTDIR="" \
  -v "$REPO_ROOT":/repo:ro \
  "$DIND_IMAGE" >/dev/null

# ── Wait for inner daemon ──────────────────────────────────────────────────
log "Waiting for inner daemon to be ready ..."
TIMEOUT=60
ELAPSED=0
until docker exec "$DIND_NAME" docker info >/dev/null 2>&1; do
  sleep 2
  ELAPSED=$((ELAPSED + 2))
  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo "--- dind logs ---"
    docker logs "$DIND_NAME"
    die "Inner daemon did not become ready after ${TIMEOUT}s."
  fi
done
log "Inner daemon ready."

# ── Install test dependencies ──────────────────────────────────────────────
log "Installing test dependencies inside dind ..."
docker exec "$DIND_NAME" \
  apk add --no-cache bash jq tar coreutils >/dev/null 2>&1

# ── Run assertions ────────────────────────────────────────────────────────
log "Running e2e assertions inside dind ..."
docker exec "$DIND_NAME" bash /repo/test/integration/e2e.sh

log "All integration tests PASSED."
