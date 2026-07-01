#!/usr/bin/env bash
# test/integration/e2e.sh
#
# Runs INSIDE the dind container.  Full backup → disaster → restore → verify
# cycle against a real Docker daemon.  No test framework dependency — just
# bash assertions.
#
# Two image strategy:
#   alpine  = the "app" container (will be wiped and restored)
#   busybox = volume helper used by the backup script
# Busybox is NOT wiped, so the restore scripts can still use it as a helper.

set -euo pipefail

REPO=/repo
BACKUP_PATH=/tmp/dbk
VOL_NAME=dbktest_vol
CTR_NAME=dbktest_ctr
BIND_DIR=/tmp/binddata
PASS=0; FAIL=0

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

# ── Assertion helpers ──────────────────────────────────────────────────────
assert() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${NC} $desc"
    FAIL=$((FAIL + 1))
  fi
}

assert_eq() {
  local desc="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then
    echo -e "  ${GREEN}✓${NC} $desc (= '$want')"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${NC} $desc (got '$got', want '$want')"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    echo -e "  ${GREEN}✓${NC} $desc (contains '$needle')"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${NC} $desc (expected '$needle' in '$haystack')"
    FAIL=$((FAIL + 1))
  fi
}

section() { echo -e "\n${YELLOW}▶ $*${NC}"; }

# ── 0. Pull base images ────────────────────────────────────────────────────
section "Pulling images"
docker pull alpine:latest  >/dev/null
docker pull busybox:latest >/dev/null
echo "  Images pulled."

# ── 1. Create fixtures ─────────────────────────────────────────────────────
section "Creating test fixtures"

# Named volume with data
docker volume create "$VOL_NAME" >/dev/null
docker run --rm \
  -v "${VOL_NAME}:/data" \
  busybox sh -c "echo 'hello-volume' > /data/file.txt"

# Bind-mount host path
mkdir -p "$BIND_DIR"
echo "hello-bind" > "$BIND_DIR/bind.txt"

# Container using both
docker run -d \
  --name "$CTR_NAME" \
  -e MYVAR=myvalue \
  -p 18080:80 \
  -v "${VOL_NAME}:/data" \
  -v "${BIND_DIR}:/mnt/bind" \
  --restart unless-stopped \
  alpine sleep 3600 >/dev/null

echo "  Volume, bind dir, and container created."

# ── 2. Backup ──────────────────────────────────────────────────────────────
section "Running backup"
cd "$REPO"
./backup-manager.sh -p "$BACKUP_PATH" -m backup -B -s

section "Verifying backup artifacts"
assert "volume tar exists"          test -f "$BACKUP_PATH/volumes/${VOL_NAME}.tar.gz"
assert "image tar exists"           test -f "$BACKUP_PATH/${CTR_NAME}/${CTR_NAME}-image.tar"
assert "inspect data exists"        test -f "$BACKUP_PATH/${CTR_NAME}/${CTR_NAME}-data.txt"
assert "bind manifest exists"       test -f "$BACKUP_PATH/${CTR_NAME}/binds/manifest.json"
assert "inspect data is valid JSON" jq '.' "$BACKUP_PATH/${CTR_NAME}/${CTR_NAME}-data.txt"

# ── 3. Disaster ────────────────────────────────────────────────────────────
section "Simulating disaster (wipe everything)"
docker rm -f "$CTR_NAME"             >/dev/null
docker volume rm "$VOL_NAME"         >/dev/null
rm -rf "$BIND_DIR"
docker rmi alpine:latest             >/dev/null   # proves image restore works

echo "  Container, volume, bind dir, and alpine image removed."

# ── 4. Restore ────────────────────────────────────────────────────────────
section "Running restore"
./backup-manager.sh -p "$BACKUP_PATH" -m restore -B -s -f

# ── 5. Verify ─────────────────────────────────────────────────────────────
section "Verifying restore results"

# Image
assert "alpine image restored" docker image inspect alpine:latest

# Volume data
vol_data=$(docker run --rm -v "${VOL_NAME}:/data" busybox cat /data/file.txt 2>/dev/null || echo "MISSING")
assert_eq "volume data restored" "$vol_data" "hello-volume"

# Bind-mount host path
bind_data=$(cat "$BIND_DIR/bind.txt" 2>/dev/null || echo "MISSING")
assert_eq "bind-mount data restored" "$bind_data" "hello-bind"

# Container running
running=$(docker inspect -f '{{.State.Running}}' "$CTR_NAME" 2>/dev/null || echo "false")
assert_eq "container is running" "$running" "true"

# Env
env_vars=$(docker inspect -f '{{json .Config.Env}}' "$CTR_NAME" 2>/dev/null || echo "[]")
assert_contains "env var MYVAR=myvalue preserved" "$env_vars" "MYVAR=myvalue"

# Restart policy
restart=$(docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' "$CTR_NAME" 2>/dev/null || echo "none")
assert_eq "restart policy preserved" "$restart" "unless-stopped"

# Port mapping
ports=$(docker inspect -f '{{json .HostConfig.PortBindings}}' "$CTR_NAME" 2>/dev/null || echo "{}")
assert_contains "port 18080 mapping preserved" "$ports" "18080"

# Named volume still mounted
mounts=$(docker inspect -f '{{json .Mounts}}' "$CTR_NAME" 2>/dev/null || echo "[]")
assert_contains "named volume still mounted" "$mounts" "$VOL_NAME"

# ── Summary ───────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────"
TOTAL=$((PASS + FAIL))
if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}All ${TOTAL} assertions passed.${NC}"
else
  echo -e "${RED}${FAIL}/${TOTAL} assertions FAILED.${NC}"
  exit 1
fi
