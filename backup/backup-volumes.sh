#!/bin/bash

# Path: backup-volumes.sh
# Backup all volumes from docker

echo "Backing up volumes"
echo "------------------"

for volume in $(docker volume inspect -f '"{{.Name}}""{{.Mountpoint}}"' $(docker volume ls -q))
do
	# Get the volume name and path
	volume_name=$(echo "$volume" | cut -f2 -d\")
	volume_path=$(echo "$volume" | cut -f4 -d\")

	# Create the backup directory
	mkdir -p "$backup_path"/volumes


	# Backup the volume
	echo -n "$volume_name - "
	docker run --rm -v "$volume_path":/volume -v "$backup_path"/volumes:/backup busybox tar -cvzf /backup/"$volume_name".tar.gz /volume >/dev/null 2>&1
	echo "OK"
done

echo ""