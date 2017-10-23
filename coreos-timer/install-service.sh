#!/bin/bash

# by piscue

# setup path of scripts
# know where backup-all.sh will be stored

cd "${BASH_SOURCE%/*}" || exit
cd ..
mkdir -p /opt/bin
cp *.sh /opt/bin
chmod +x /opt/bin/*sh

# copy service and time to the system
cd config
cp backup-containers* /etc/systemd/system/

# enabling timer
systemctl enable /etc/systemd/system/backup-containers.timer
systemctl start  /etc/systemd/system/backup-containers.timer
systemctl enable /etc/systemd/system/backup-containers.service
