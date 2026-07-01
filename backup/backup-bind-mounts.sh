#!/bin/bash

# Path: backup-bind-mounts.sh
# Backup host filesystem paths that are bind-mounted into containers.
#
# Each container's bind mounts are archived into:
#   <backup_path>/<container>/binds/bind-N.tar.gz
# with a manifest.json that maps each archive back to its original host path.
#
# Note: this script must run with sufficient permissions to read the bind-mount
# source paths (often requires root).

echo "Backing up bind mounts"
echo "----------------------"

found_any=false

for container_name in $(docker ps -q | xargs docker inspect --format='{{.Name}}' | cut -f2 -d/)
do
  # Extract bind-mount source paths using a Go template (no jq needed here)
  bind_sources=$(docker inspect \
    --format='{{range .Mounts}}{{if eq .Type "bind"}}{{println .Source}}{{end}}{{end}}' \
    "$container_name")

  [ -z "$bind_sources" ] && continue

  found_any=true
  echo "$container_name:"

  binds_dir="$backup_path/$container_name/binds"
  mkdir -p "$binds_dir"

  manifest="$binds_dir/manifest.json"
  printf '[\n' > "$manifest"
  first=true
  i=0

  while IFS= read -r host_path
  do
    [ -z "$host_path" ] && continue

    archive_name="bind-$i.tar.gz"
    archive_path="$binds_dir/$archive_name"

    echo -n "  $host_path - "

    if [ ! -e "$host_path" ]; then
      echo "SKIPPED (path does not exist)"
    else
      # Archive with absolute paths (-P) so restore can put files back exactly
      tar -P -czf "$archive_path" "$host_path" 2>/dev/null
      echo "OK"
    fi

    # Append manifest entry (comma-separate after the first)
    if [ "$first" = true ]; then
      first=false
    else
      printf ',\n' >> "$manifest"
    fi
    printf '  {"archive":"%s","path":"%s"}' "$archive_name" "$host_path" >> "$manifest"

    i=$((i + 1))
  done <<< "$bind_sources"

  printf '\n]\n' >> "$manifest"
done

if [ "$found_any" = false ]; then
  echo "No bind mounts found on running containers"
fi

echo ""
