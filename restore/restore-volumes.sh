#!/bin/bash

# Path: restore-volumes.sh
# Restore all volumes from the backup
# Inside the backup directory, there is a volumes directory, which contains all the volumes.

echo "Volumes restaurations"
echo "------------------"

volumes=$(ls "$backup_path/volumes")

for volume in $volumes
do
	# Get volume name from the file name
	volume=$(echo "$volume" | cut -f1 -d.)

	echo -n "$volume - "
	docker run --rm -v "$volume":/volume -v "$backup_path"/volumes:/backup busybox sh -c "cd /volume && tar -xvf /backup/$volume.tar.gz --strip 1" >/dev/null 2>&1
	echo "OK"
done