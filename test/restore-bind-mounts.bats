#!/usr/bin/env bats
# Tests for restore/restore-bind-mounts.sh

setup() {
  cd "$BATS_TEST_DIRNAME/.."

  TEST_TMPDIR=$(mktemp -d)
  export TEST_TMPDIR
  export backup_path="$TEST_TMPDIR/backup"
  mkdir -p "$backup_path/test-container/binds"

  export DOCKER_LOG="$TEST_TMPDIR/docker.log"
  export PATH="$BATS_TEST_DIRNAME/helpers:$PATH"
  export force=false

  # Define restore destinations inside TEST_TMPDIR so tar -C / can write there
  # (TEST_TMPDIR is writable; paths like /var/folders/.../config are real on macOS
  # and /tmp/.../config are real on Linux).
  CONFIG_HOST_PATH="$TEST_TMPDIR/host/config"
  DATA_HOST_PATH="$TEST_TMPDIR/host/data"

  # Create source content that "was" at the host paths before backup
  mkdir -p "$CONFIG_HOST_PATH" "$DATA_HOST_PATH"
  echo "config-value" > "$CONFIG_HOST_PATH/app.conf"
  echo "data-value"   > "$DATA_HOST_PATH/data.txt"

  # Create archives exactly as backup-bind-mounts.sh would:
  # tar -P preserves absolute paths so restore can put files back in place
  tar -P -czf "$backup_path/test-container/binds/bind-0.tar.gz" "$CONFIG_HOST_PATH"
  tar -P -czf "$backup_path/test-container/binds/bind-1.tar.gz" "$DATA_HOST_PATH"

  # Write manifest pointing to the same host paths
  cat > "$backup_path/test-container/binds/manifest.json" <<EOF
[
  {"archive":"bind-0.tar.gz","path":"$CONFIG_HOST_PATH"},
  {"archive":"bind-1.tar.gz","path":"$DATA_HOST_PATH"}
]
EOF

  # Remove the host paths so restore can recreate them
  rm -rf "$TEST_TMPDIR/host"
  mkdir -p "$TEST_TMPDIR/host"

  export CONFIG_HOST_PATH DATA_HOST_PATH
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "restores files to the manifest host path" {
  source restore/restore-bind-mounts.sh

  [ -f "$CONFIG_HOST_PATH/app.conf" ]
  run cat "$CONFIG_HOST_PATH/app.conf"
  [ "$output" = "config-value" ]
}

@test "restores all entries from manifest" {
  source restore/restore-bind-mounts.sh

  [ -f "$DATA_HOST_PATH/data.txt" ]
  run cat "$DATA_HOST_PATH/data.txt"
  [ "$output" = "data-value" ]
}

@test "skips existing path without -f flag" {
  # Pre-create the target so restore should skip it
  mkdir -p "$CONFIG_HOST_PATH"
  echo "original" > "$CONFIG_HOST_PATH/app.conf"

  force=false
  run bash -c "
    cd '$BATS_TEST_DIRNAME/..'
    export backup_path='$backup_path'
    export force=false
    source restore/restore-bind-mounts.sh
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIPPED"* ]]
  # Original content must be untouched
  [ "$(cat "$CONFIG_HOST_PATH/app.conf")" = "original" ]
}

@test "overwrites existing path with -f flag" {
  mkdir -p "$CONFIG_HOST_PATH"
  echo "original" > "$CONFIG_HOST_PATH/app.conf"

  force=true
  source restore/restore-bind-mounts.sh

  run cat "$CONFIG_HOST_PATH/app.conf"
  [ "$output" = "config-value" ]
}

@test "handles missing archive file gracefully" {
  rm "$backup_path/test-container/binds/bind-0.tar.gz"

  run bash -c "
    cd '$BATS_TEST_DIRNAME/..'
    export backup_path='$backup_path'
    export force=false
    source restore/restore-bind-mounts.sh
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIPPED"* ]]
}

@test "handles backup path with no bind mount data gracefully" {
  rm -rf "$backup_path/test-container/binds"

  run bash -c "
    cd '$BATS_TEST_DIRNAME/..'
    export backup_path='$backup_path'
    export force=false
    source restore/restore-bind-mounts.sh
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"No bind mount backups found"* ]]
}
