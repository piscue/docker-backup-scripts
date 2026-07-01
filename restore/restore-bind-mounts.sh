#!/bin/bash

# Path: restore-bind-mounts.sh
# Restore host filesystem paths that were bind-mounted into containers.
#
# Reads the manifest.json written by backup-bind-mounts.sh and extracts each
# archive back to its original host path.
#
# Note: this script must run with sufficient permissions to write to the
# restored host paths (often requires root).

echo "Restoring bind mounts"
echo "---------------------"

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required to restore bind mounts."
  echo "       Install it with your package manager (e.g. apt install jq / brew install jq)."
  return 1 2>/dev/null || exit 1
fi

found_any=false

for container_dir in "$backup_path"/*/
do
  [ -d "$container_dir" ] || continue
  container_name=$(basename "$container_dir")
  [ "$container_name" = "volumes" ] && continue

  manifest="$container_dir/binds/manifest.json"
  [ -f "$manifest" ] || continue

  found_any=true
  echo "$container_name:"

  while IFS= read -r entry
  do
    archive=$(printf '%s' "$entry" | jq -r '.archive')
    host_path=$(printf '%s' "$entry" | jq -r '.path')
    archive_file="$container_dir/binds/$archive"

    echo -n "  $host_path - "

    if [ ! -f "$archive_file" ]; then
      echo "SKIPPED (archive not found: $archive)"
      continue
    fi

    if [ -e "$host_path" ] && [ "$force" != true ]; then
      echo "SKIPPED (already exists; use -f to overwrite)"
      continue
    fi

    mkdir -p "$(dirname "$host_path")"
    if tar -P -xzf "$archive_file" 2>/dev/null; then
      echo "OK"
    else
      echo "FAILED (extraction error — check permissions)"
    fi
  done < <(jq -c '.[]' "$manifest")
done

if [ "$found_any" = false ]; then
  echo "No bind mount backups found in $backup_path"
fi

echo ""
