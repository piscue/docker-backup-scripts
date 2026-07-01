#!/usr/bin/env bats
# Tests for backup/backup-bind-mounts.sh

setup() {
  cd "$BATS_TEST_DIRNAME/.."

  TEST_TMPDIR=$(mktemp -d)
  export TEST_TMPDIR
  export backup_path="$TEST_TMPDIR/backup"
  mkdir -p "$backup_path"

  export DOCKER_LOG="$TEST_TMPDIR/docker.log"
  export STUB_CONTAINERS="test-container"
  export PATH="$BATS_TEST_DIRNAME/helpers:$PATH"

  # Create real host paths to act as bind-mount sources
  export FAKE_CONFIG_DIR="$TEST_TMPDIR/host/config"
  export FAKE_DATA_DIR="$TEST_TMPDIR/host/data"
  mkdir -p "$FAKE_CONFIG_DIR" "$FAKE_DATA_DIR"
  echo "config-value" > "$FAKE_CONFIG_DIR/app.conf"
  echo "data-value"   > "$FAKE_DATA_DIR/data.txt"

  # Tell the stub which bind sources to return for this container
  export STUB_BIND_SOURCES="$FAKE_CONFIG_DIR
$FAKE_DATA_DIR"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "creates binds/ directory per container" {
  source backup/backup-bind-mounts.sh

  [ -d "$backup_path/test-container/binds" ]
}

@test "creates one archive per bind-mount source" {
  source backup/backup-bind-mounts.sh

  [ -f "$backup_path/test-container/binds/bind-0.tar.gz" ]
  [ -f "$backup_path/test-container/binds/bind-1.tar.gz" ]
}

@test "archives contain the correct files" {
  source backup/backup-bind-mounts.sh

  # bind-0 should contain the config file
  run tar -tzf "$backup_path/test-container/binds/bind-0.tar.gz"
  [[ "$output" == *"app.conf"* ]]

  # bind-1 should contain the data file
  run tar -tzf "$backup_path/test-container/binds/bind-1.tar.gz"
  [[ "$output" == *"data.txt"* ]]
}

@test "creates a valid manifest.json" {
  source backup/backup-bind-mounts.sh

  manifest="$backup_path/test-container/binds/manifest.json"
  [ -f "$manifest" ]

  # Must be valid JSON
  run jq '.' "$manifest"
  [ "$status" -eq 0 ]
}

@test "manifest maps archive names to original host paths" {
  source backup/backup-bind-mounts.sh

  manifest="$backup_path/test-container/binds/manifest.json"

  run jq -r '.[0].archive' "$manifest"
  [ "$output" = "bind-0.tar.gz" ]

  run jq -r '.[0].path' "$manifest"
  [ "$output" = "$FAKE_CONFIG_DIR" ]

  run jq -r '.[1].path' "$manifest"
  [ "$output" = "$FAKE_DATA_DIR" ]
}

@test "skips non-existent bind-mount source paths gracefully" {
  # Override bind sources with a non-existent path in the outer scope so the
  # subshell inherits the already-correct PATH (with docker stub prepended).
  export STUB_BIND_SOURCES="/nonexistent/path"

  run bash -c "
    cd '$BATS_TEST_DIRNAME/..'
    export backup_path='$backup_path'
    export STUB_CONTAINERS='$STUB_CONTAINERS'
    export DOCKER_LOG='$DOCKER_LOG'
    source backup/backup-bind-mounts.sh
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIPPED"* ]]
}

@test "handles containers with no bind mounts gracefully" {
  export STUB_BIND_SOURCES=""

  source backup/backup-bind-mounts.sh

  # No binds directory should be created for this container
  [ ! -d "$backup_path/test-container/binds" ]
}
