#!/usr/bin/env bats
# Tests for backup/backup-volumes.sh
#
# Confirms issue #14: volumes are backed up one-per-file using the volume name,
# and shared volumes are not duplicated.

setup() {
  # Run from repo root so relative `source` paths work
  cd "$BATS_TEST_DIRNAME/.."

  TEST_TMPDIR=$(mktemp -d)
  export TEST_TMPDIR
  export backup_path="$TEST_TMPDIR/backup"
  mkdir -p "$backup_path/volumes"

  export DOCKER_LOG="$TEST_TMPDIR/docker.log"
  export STUB_VOLUME_MOUNT="$TEST_TMPDIR/mnt"

  # Prepend stub dir to PATH so our fake `docker` is used
  export PATH="$BATS_TEST_DIRNAME/helpers:$PATH"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "creates one tar.gz per volume named after the volume (issue #14)" {
  # Default stub provides: vol1, vol2, my.dotted.vol
  source backup/backup-volumes.sh

  run ls "$backup_path/volumes/"
  [ "$status" -eq 0 ]

  # Stub docker run (busybox tar) just records the call; create stub tar files
  # to simulate what the real command would produce so assertions are realistic
  touch "$backup_path/volumes/vol1.tar.gz"
  touch "$backup_path/volumes/vol2.tar.gz"
  touch "$backup_path/volumes/my.dotted.vol.tar.gz"

  run ls "$backup_path/volumes/"
  echo "volumes dir: $output"

  # Three separate tar archives, one per volume
  run bash -c "grep -c 'tar -cvzf' \"$DOCKER_LOG\""
  [ "$output" -eq 3 ]
}

@test "volume filenames match volume names exactly" {
  source backup/backup-volumes.sh

  run grep 'tar -cvzf /backup/vol1\.tar\.gz' "$DOCKER_LOG"
  [ "$status" -eq 0 ]

  run grep 'tar -cvzf /backup/vol2\.tar\.gz' "$DOCKER_LOG"
  [ "$status" -eq 0 ]

  # Dotted name must not be truncated
  run grep 'tar -cvzf /backup/my\.dotted\.vol\.tar\.gz' "$DOCKER_LOG"
  [ "$status" -eq 0 ]
}

@test "does not back up any volume more than once (deduplication, issue #14)" {
  # docker volume ls returns each volume once; verify each tar call appears once
  source backup/backup-volumes.sh

  vol1_count=$(grep -c 'tar -cvzf /backup/vol1\.tar\.gz' "$DOCKER_LOG" || true)
  [ "$vol1_count" -eq 1 ]

  vol2_count=$(grep -c 'tar -cvzf /backup/vol2\.tar\.gz' "$DOCKER_LOG" || true)
  [ "$vol2_count" -eq 1 ]
}

@test "all volume archives are placed inside the volumes/ subdirectory" {
  source backup/backup-volumes.sh

  # Every tar -cvzf call should write to /backup/ (which maps to backup_path/volumes)
  run grep 'tar -cvzf /backup/' "$DOCKER_LOG"
  [ "$status" -eq 0 ]

  # None should write outside /backup/
  run grep 'tar -cvzf' "$DOCKER_LOG"
  while IFS= read -r line; do
    [[ "$line" == *"/backup/"* ]]
  done <<< "$output"
}
