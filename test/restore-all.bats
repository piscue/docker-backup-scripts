#!/usr/bin/env bats
# Tests for restore/restore-all.sh
#
# Guards against issue #18 regressing: all three restore steps (images,
# volumes, containers) must be triggered in non-interactive mode.

setup() {
  cd "$BATS_TEST_DIRNAME/.."

  TEST_TMPDIR=$(mktemp -d)
  export TEST_TMPDIR
  export backup_path="$TEST_TMPDIR/backup"
  mkdir -p "$backup_path/volumes"
  mkdir -p "$backup_path/test-container"

  export DOCKER_LOG="$TEST_TMPDIR/docker.log"
  export PATH="$BATS_TEST_DIRNAME/helpers:$PATH"

  export non_interactive=true
  export force=false

  # Create stub backup artifacts so each restore step finds something to do
  touch "$backup_path/volumes/myvol.tar.gz"
  touch "$backup_path/test-container/test-container-image.tar"
  cp test/fixtures/container_inspect.json \
    "$backup_path/test-container/test-container-data.txt"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "non-interactive restore loads images (step 1)" {
  source restore/restore-all.sh

  run grep 'docker load' "$DOCKER_LOG"
  [ "$status" -eq 0 ]
}

@test "non-interactive restore restores volumes (step 2)" {
  source restore/restore-all.sh

  # The volume restore calls busybox tar via docker run
  run grep 'myvol' "$DOCKER_LOG"
  [ "$status" -eq 0 ]
}

@test "non-interactive restore recreates containers (step 3, fixes issue #18)" {
  source restore/restore-all.sh

  # Container recreation emits a docker run -d call
  run grep 'docker run -d' "$DOCKER_LOG"
  [ "$status" -eq 0 ]
}

@test "restore fails if backup path does not exist" {
  run bash -c "
    export backup_path='/nonexistent/path'
    export non_interactive=true
    export force=false
    export PATH='$BATS_TEST_DIRNAME/helpers:\$PATH'
    cd '$BATS_TEST_DIRNAME/..'
    source restore/restore-all.sh
  "
  [ "$status" -ne 0 ]
  [[ "$output" == *"Error"* ]]
}
