#!/bin/bash

# Path: restore-images.sh
# Restore all container images from the backup.
# Each container directory inside the backup path contains a *-image.tar file
# produced by "docker save".

echo "Restoring container images"
echo "--------------------------"

image_files=( "$backup_path"/*/*-image.tar )
if [ ! -e "${image_files[0]}" ]; then
  echo "No image backups found in $backup_path"
  echo ""
  return 0 2>/dev/null || exit 0
fi

for image_file in "${image_files[@]}"
do
  image_name=$(basename "$image_file" "-image.tar")
  echo -n "$image_name - "
  docker load -i "$image_file" >/dev/null 2>&1
  echo "OK"
done

echo ""
