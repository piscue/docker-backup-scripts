#!/bin/bash

# Path: restore-volumes.sh
# Restore all volumes from the backup.
# The backup directory contains a volumes/ subdirectory with one .tar.gz file
# per volume, named after the volume (e.g. myvolume.tar.gz).

echo "Volumes restoration"
echo "------------------"

if [ ! -d "$backup_path/volumes" ]; then
  echo "No volumes backup found in $backup_path/volumes"
  echo ""
  return 0 2>/dev/null || exit 0
fi

found=false
for file in "$backup_path/volumes/"*.tar.gz
do
  [ -e "$file" ] || continue
  found=true

  # Derive the volume name by stripping the .tar.gz suffix.
  # Using parameter expansion instead of cut so dotted names work correctly
  # (e.g. "my.vol.1.tar.gz" → "my.vol.1", not "my").
  filename=$(basename "$file")
  volume="${filename%.tar.gz}"

  echo -n "$volume - "
  docker volume create "$volume" >/dev/null 2>&1
  docker run --rm \
    --userns=host \
    -v "$volume":/volume \
    -v "$backup_path/volumes":/backup \
    busybox sh -c "cd /volume && tar -xvf /backup/$filename --strip 1" >/dev/null 2>&1
  echo "OK"
done

if [ "$found" = false ]; then
  echo "No volume backups found in $backup_path/volumes"
fi

echo ""