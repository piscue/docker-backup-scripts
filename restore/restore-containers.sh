#!/bin/bash

# Path: restore-containers.sh
# Recreate containers from the saved docker inspect data (best-effort).
#
# Note: Container recreation from inspect data covers the most common
# configuration fields (name, image, env, ports, volumes, restart policy,
# network). Unusual configurations (custom capabilities, device mappings,
# secrets, etc.) may need to be applied manually after restoration.
#
# Requires: jq

echo "Recreating containers"
echo "---------------------"

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required for container restoration."
  echo "       Install it with your package manager (e.g. apt install jq / brew install jq)."
  return 1 2>/dev/null || exit 1
fi

# build_run_cmd <json_file>
# Reads the first container entry from a docker-inspect JSON file and prints
# the equivalent "docker run" command to stdout.
build_run_cmd() {
  local json_file="$1"
  local data
  data=$(cat "$json_file")

  local name restart image
  name=$(printf '%s' "$data" | jq -r '.[0].Name | ltrimstr("/")')
  restart=$(printf '%s' "$data" | jq -r '.[0].HostConfig.RestartPolicy.Name // empty')
  image=$(printf '%s' "$data" | jq -r '.[0].Config.Image')

  local cmd="docker run -d"
  cmd="$cmd --name \"$name\""

  if [ -n "$restart" ] && [ "$restart" != "no" ]; then
    cmd="$cmd --restart $restart"
  fi

  # Environment variables
  while IFS= read -r env_var; do
    [ -n "$env_var" ] && cmd="$cmd -e \"$env_var\""
  done < <(printf '%s' "$data" | jq -r '.[0].Config.Env[]? // empty')

  # Port bindings: HostConfig.PortBindings maps "containerPort/proto" to
  # [{ "HostIp": "", "HostPort": "hostPort" }]
  while IFS= read -r port_mapping; do
    [ -n "$port_mapping" ] && cmd="$cmd -p $port_mapping"
  done < <(printf '%s' "$data" | jq -r '
    .[0].HostConfig.PortBindings // {} |
    to_entries[] |
    .key as $cport |
    .value[]? |
    (if .HostIp != "" and .HostIp != null then .HostIp + ":" else "" end) +
    .HostPort + ":" + ($cport | split("/")[0])
  ')

  # Bind mounts (host-path:container-path[:options])
  while IFS= read -r bind; do
    [ -n "$bind" ] && cmd="$cmd -v \"$bind\""
  done < <(printf '%s' "$data" | jq -r '.[0].HostConfig.Binds[]? // empty')

  # Named volumes (Type == "volume" in Mounts)
  while IFS= read -r vol_mount; do
    [ -n "$vol_mount" ] && cmd="$cmd -v $vol_mount"
  done < <(printf '%s' "$data" | jq -r '
    .[0].Mounts[]? |
    select(.Type == "volume") |
    "\(.Name):\(.Destination)"
  ')

  # Network mode (skip default/bridge — those are Docker defaults)
  local network_mode
  network_mode=$(printf '%s' "$data" | jq -r '.[0].HostConfig.NetworkMode // empty')
  if [ -n "$network_mode" ] && [ "$network_mode" != "default" ] && [ "$network_mode" != "bridge" ]; then
    cmd="$cmd --network $network_mode"
  fi

  cmd="$cmd $image"

  # Override CMD only if explicitly set in the inspect data
  local container_cmd
  container_cmd=$(printf '%s' "$data" | jq -r '.[0].Config.Cmd // [] | join(" ")')
  if [ -n "$container_cmd" ]; then
    cmd="$cmd $container_cmd"
  fi

  printf '%s\n' "$cmd"
}

data_files=( "$backup_path"/*/*-data.txt )
if [ ! -e "${data_files[0]}" ]; then
  echo "No container data backups found in $backup_path"
  echo ""
  return 0 2>/dev/null || exit 0
fi

for data_file in "${data_files[@]}"
do
  container_name=$(basename "$(dirname "$data_file")")
  echo -n "$container_name - "

  if docker inspect "$container_name" >/dev/null 2>&1; then
    if [ "$force" = true ]; then
      docker rm -f "$container_name" >/dev/null 2>&1
    else
      echo "SKIPPED (already exists; use -f to replace)"
      continue
    fi
  fi

  run_cmd=$(build_run_cmd "$data_file")
  eval "$run_cmd" >/dev/null 2>&1
  echo "OK"
done

echo ""
