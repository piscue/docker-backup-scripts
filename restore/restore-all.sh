#!/bin/bash

# by piscue

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
  echo "Restore volumes ? (y/n)"
  read -r restore_volumes
else
  restore_volumes="y"
fi

if [ "$restore_volumes" = "y" ]
then
  source restore/restore-volumes.sh
fi



echo ""
echo "Restoration finished"