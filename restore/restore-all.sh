#!/bin/bash

echo "Starting docker restore"
echo ""

# Check if backup path exists
if [ ! -d "$backup_path" ]
then
  echo "Error: backup path does not exist"
  exit 1
fi


if [ "$non_interactive" = false ]
then
  echo "Restore container images ? (y/n)"
  read -r restore_images

  echo "Restore volumes ? (y/n)"
  read -r restore_volumes

  echo "Restore bind-mounted host paths ? (y/n) [requires write access to those paths]"
  read -r restore_bind_mounts

  echo "Recreate containers from saved inspect data ? (y/n)"
  read -r restore_containers
else
  restore_images="y"
  restore_volumes="y"
  restore_bind_mounts=$([ "$bind_mounts_enable" = true ] && echo "y" || echo "n")
  restore_containers="y"
fi

if [ "$restore_images" = "y" ]
then
  source restore/restore-images.sh
fi

if [ "$restore_volumes" = "y" ]
then
  source restore/restore-volumes.sh
fi

if [ "$restore_bind_mounts" = "y" ]
then
  source restore/restore-bind-mounts.sh
fi

if [ "$restore_containers" = "y" ]
then
  source restore/restore-containers.sh
fi



echo ""
echo "Restoration finished"
