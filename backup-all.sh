#!/bin/bash

# by piscue

# Setting variables
backup_path="/opt/backups"
#backup_path="/home/core/backups"
tar_opts="--exclude='/var/run/*'"
cd /opt/docker-backup-scripts


mkdir -p $backup_path

echo starting docker backup

echo ""

echo - backing up images

echo ""

source backup-images.sh

echo ""

echo - backing up volumes

echo ""

source backup-volumes.sh

echo ""

