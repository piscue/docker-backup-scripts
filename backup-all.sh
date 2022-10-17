#!/bin/bash

# by piscue

# Setting variables
backup_path="/home/core/backups"
tar_opts="--exclude='/var/run/*'"
cd "${BASH_SOURCE%/*}" || exit

mkdir -p $backup_path

echo starting docker backup
echo ""

echo "- backing up container data (inspection output)"
echo ""
source backup-container-data.sh
echo ""

echo - backing up images
echo ""
source backup-images.sh
echo ""

echo - backing up volumes
echo ""
source backup-volumes.sh
echo ""

echo - upload to dropbox
echo ""
source sync-dropbox.sh
echo ""
