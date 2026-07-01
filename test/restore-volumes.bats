#!/usr/bin/env bats
# Tests for restore/restore-volumes.sh
#
# Regression test for the "cut -f1 -d." parsing bug that truncated dotted
# volume names (e.g. "my.vol.1" would become "my").

setup() {
  cd "$BATS_TEST_DIRNAME/.."

  TEST_TMPDIR=$(mktemp -d)
  export TEST_TMPDIR
  export backup_path="$TEST_TMPDIR/backup"
  mkdir -p "$backup_path/volumes"

  export DOCKER_LOG="$TEST_TMPDIR/docker.log"
  export PATH="$BATS_TEST_DIRNAME/helpers:$PATH"

  # Shared variables required by the script
  export non_interactive=true
  export force=false
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "restores a simple volume by name" {
  touch "$backup_path/volumes/myvolume.tar.gz"

  source restore/restore-volumes.sh

  run grep 'myvolume' "$DOCKER_LOG"
  [ "$status" -eq 0 ]
}

@test "correctly handles dotted volume names (regression for cut -f1 -d. bug)" {
  touch "$backup_path/volumes/my.dotted.vol.tar.gz"

  source restore/restore-volumes.sh

  # The volume name passed to docker run must be the full name, not just "my"
  run grep 'my\.dotted\.vol' "$DOCKER_LOG"
  [ "$status" -eq 0 ]

  # Ensure "my.tar.gz" is NOT referenced (would indicate the old truncation bug)
  run grep '"my"' "$DOCKER_LOG"
  [ "$status" -ne 0 ]
}

@test "passes the correct filename to the tar extraction command" {
  touch "$backup_path/volumes/my.dotted.vol.tar.gz"

  source restore/restore-volumes.sh

  # The busybox tar call must reference the full filename
  run grep 'my\.dotted\.vol\.tar\.gz' "$DOCKER_LOG"
  [ "$status" -eq 0 ]
}

@test "creates docker volume before restoring" {
  touch "$backup_path/volumes/newvol.tar.gz"

  source restore/restore-volumes.sh

  run grep 'volume create newvol' "$DOCKER_LOG"
  [ "$status" -eq 0 ]
}

@test "handles missing volumes directory gracefully" {
  rm -rf "$backup_path/volumes"

  run bash -c "
    backup_path='$backup_path'
    non_interactive=true
    force=false
    PATH='$BATS_TEST_DIRNAME/helpers:$PATH'
    source restore/restore-volumes.sh
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"No volumes backup found"* ]]
}

@test "handles empty volumes directory gracefully" {
  # volumes/ exists but has no .tar.gz files
  run bash -c "
    backup_path='$backup_path'
    non_interactive=true
    force=false
    PATH='$BATS_TEST_DIRNAME/helpers:$PATH'
    source restore/restore-volumes.sh
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"No volume backups found"* ]]
}
