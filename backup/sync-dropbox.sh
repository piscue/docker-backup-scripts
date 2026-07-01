#!/bin/bash

# Path: sync-dropbox.sh
# Upload the backup directory to Dropbox and remove local files after a
# successful upload.  Requires a valid config/dropbox_uploader.conf.

echo "Syncing to Dropbox"
echo "------------------"

_dropbox_mkdir() {
  docker run --rm --user="$(id -u)":"$(id -g)" \
    -v "$PWD/config":/config \
    -v "$backup_path":/workdir \
    peez/dropbox-uploader \
    mkdir "$1" 2>/dev/null || true
}

_dropbox_upload() {
  local src="$1"   # path relative to $backup_path
  local dest="$2"  # path in Dropbox
  docker run --rm --user="$(id -u)":"$(id -g)" \
    --name "dropbox-upload-$(echo "$src" | tr '/' '-')" \
    -v "$PWD/config":/config \
    -v "$backup_path":/workdir \
    peez/dropbox-uploader \
    upload "$src" "$dest"
}

# Upload per-volume tar archives
if [ -d "$backup_path/volumes" ]; then
  _dropbox_mkdir "volumes"

  for vol_file in "$backup_path/volumes/"*.tar.gz; do
    [ -e "$vol_file" ] || continue
    filename=$(basename "$vol_file")
    echo -n "volumes/$filename - "
    if _dropbox_upload "volumes/$filename" "volumes/$filename"; then
      rm -f "$vol_file"
      echo "OK"
    else
      echo "FAILED"
    fi
  done
fi

# Upload per-container image and inspect-data files
for container_dir in "$backup_path"/*/; do
  [ -d "$container_dir" ] || continue
  container_name=$(basename "$container_dir")
  [ "$container_name" = "volumes" ] && continue

  _dropbox_mkdir "$container_name"

  for file in "$container_dir"*; do
    [ -e "$file" ] || continue
    filename=$(basename "$file")
    echo -n "$container_name/$filename - "
    if _dropbox_upload "$container_name/$filename" "$container_name/$filename"; then
      rm -f "$file"
      echo "OK"
    else
      echo "FAILED"
    fi
  done
done

echo ""
