#!/usr/bin/env bats
# Tests for restore/restore-containers.sh
#
# Validates that build_run_cmd correctly reconstructs a docker run command
# from a saved docker inspect JSON file.

setup() {
  cd "$BATS_TEST_DIRNAME/.."

  TEST_TMPDIR=$(mktemp -d)
  export TEST_TMPDIR
  export backup_path="$TEST_TMPDIR/backup"

  export DOCKER_LOG="$TEST_TMPDIR/docker.log"
  export PATH="$BATS_TEST_DIRNAME/helpers:$PATH"

  export non_interactive=true
  export force=false
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# Source the script with an empty backup_path so the main loop returns early
# but build_run_cmd is defined.
_load_functions() {
  mkdir -p "$backup_path"
  # shellcheck disable=SC1091
  source restore/restore-containers.sh 2>/dev/null || true
}

@test "build_run_cmd includes --name flag" {
  _load_functions
  result=$(build_run_cmd "test/fixtures/container_inspect.json")
  [[ "$result" == *'--name "test-container"'* ]]
}

@test "build_run_cmd includes --restart flag" {
  _load_functions
  result=$(build_run_cmd "test/fixtures/container_inspect.json")
  [[ "$result" == *"--restart always"* ]]
}

@test "build_run_cmd includes environment variables with -e" {
  _load_functions
  result=$(build_run_cmd "test/fixtures/container_inspect.json")
  [[ "$result" == *'-e "FOO=bar"'* ]]
  [[ "$result" == *'-e "BAZ=qux"'* ]]
}

@test "build_run_cmd includes port mappings with -p" {
  _load_functions
  result=$(build_run_cmd "test/fixtures/container_inspect.json")
  # Port 80/tcp → host 8080
  [[ "$result" == *"-p 8080:80"* ]]
  # Port 443/tcp → host 8443 with explicit HostIp
  [[ "$result" == *"-p 0.0.0.0:8443:443"* ]]
}

@test "build_run_cmd includes bind mounts with -v" {
  _load_functions
  result=$(build_run_cmd "test/fixtures/container_inspect.json")
  [[ "$result" == *'-v "/host/data:/container/data:ro"'* ]]
}

@test "build_run_cmd includes named volume mounts with -v" {
  _load_functions
  result=$(build_run_cmd "test/fixtures/container_inspect.json")
  [[ "$result" == *"-v myvolume:/data"* ]]
}

@test "build_run_cmd includes --network flag" {
  _load_functions
  result=$(build_run_cmd "test/fixtures/container_inspect.json")
  [[ "$result" == *"--network mynetwork"* ]]
}

@test "build_run_cmd includes the image" {
  _load_functions
  result=$(build_run_cmd "test/fixtures/container_inspect.json")
  [[ "$result" == *"nginx:latest"* ]]
}

@test "build_run_cmd starts with 'docker run -d'" {
  _load_functions
  result=$(build_run_cmd "test/fixtures/container_inspect.json")
  [[ "$result" == "docker run -d"* ]]
}

@test "full restore creates container via docker run -d" {
  # Set up a backup dir with one container's data file
  mkdir -p "$backup_path/test-container"
  cp test/fixtures/container_inspect.json \
    "$backup_path/test-container/test-container-data.txt"

  source restore/restore-containers.sh

  run grep 'docker run -d' "$DOCKER_LOG"
  [ "$status" -eq 0 ]
}

@test "skips existing container without -f flag" {
  # Set up backup dir in the outer test scope (setup() makes a fresh tmpdir)
  mkdir -p "$backup_path/test-container"
  cp test/fixtures/container_inspect.json \
    "$backup_path/test-container/test-container-data.txt"

  # Override force to false and simulate an already-running container.
  # All other vars (backup_path, PATH, DOCKER_LOG) are already exported by setup().
  force=false
  export STUB_CONTAINER_EXISTS=true

  # Capture output by running in a subshell that inherits the full environment
  run bash -c "cd '$BATS_TEST_DIRNAME/..' && source restore/restore-containers.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIPPED"* ]]
}
