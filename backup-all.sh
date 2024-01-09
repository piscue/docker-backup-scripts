#!/bin/bash

# by piscue


# Setting flags

# -s : non-interactive mode
# -p : backup path
# -t : tar options
# -u : upload to dropbox

non_interactive=false
backup_path="/home/core/backups"
tar_opts="--exclude='/var/run/*'"
docker_upload_enable=false
force=false

while getopts "sp:t:uf" opt; do
  case $opt in
    s)
      non_interactive=true
      ;;
    p)
      backup_path=$OPTARG
      ;;
    t)
      tar_opts=$OPTARG
      ;;
    u)
      docker_upload_enable=true
      ;;
    f)
      force=true
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

cd "${BASH_SOURCE%/*}" || exit

echo "Starting docker backup"
echo "  - backup path: $backup_path"
echo "  - tar options: $tar_opts"
echo ""

# Check if backup path exists
if [ ! -d "$backup_path" ]
then
  # Attempt to create the directory
  mkdir -p "$backup_path"
  if [ $? -ne 0 ]
  then
    echo "Error: backup path does not exist and could not be created"
    exit 1
  fi
else
  # Check if backup path is empty
  if [ "$(ls -A "$backup_path")" ]
  then
    # Backup path is not empty
    if [ "$force" = false ]
    then
      echo "Error: backup path is not empty, use -f to force"
      exit 1
    else
      echo "Warning: backup path is not empty, but force flag is set"
    fi
  fi

  # Check if backup path is writable
  touch "$backup_path/test.txt" 2>/dev/null
  if [ $? -ne 0 ]
  then
    echo "Error: backup path is not writable"
    exit 1
  else
    rm "$backup_path/test.txt"
  fi
fi


if [ "$non_interactive" = false ]
then
  echo "Backup container data (inspection output) ? (y/n)"
  read -r backup_container_data

  echo "Backup container images ? (y/n)"
  read -r backup_container_images

  echo "Backup volumes ? (y/n)"
  read -r backup_volumes

  echo "Should I compress the backup directory ? (y/n)"
  read -r compress_backup
else
  backup_container_data="y"
  backup_container_images="y"
  backup_volumes="y"
  compress_backup="n"
fi

if [ "$backup_container_data" = "y" ]
then
  source backup-container-data.sh
fi

if [ "$backup_container_images" = "y" ]
then
  source backup-images.sh
fi

if [ "$backup_volumes" = "y" ]
then
  source backup-volumes.sh
fi

if [ "$compress_backup" = "y" ]
then
  echo -n "Compressing backup directory - "
  tar -czf "$backup_path.tar.gz" "$backup_path" >/dev/null 2>&1
  echo "OK"

  echo -n "Removing backup directory - "
  rm -rf "$backup_path"
  echo "OK"
fi

echo ""
echo "Backup finished"

if [ "$compress_backup" = "y" ]
then
  echo "Backup file: $backup_path.tar.gz"
else
  echo "Backup directory: $backup_path"
fi

if [ "$docker_upload_enable" = true ]
then
  echo - upload to dropbox
  echo ""
  source sync-dropbox.sh
  echo ""
fi