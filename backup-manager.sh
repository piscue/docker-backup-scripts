#! /bin/bash

# Backup Manager
# Author: piscue
# The backup manager is a script that allows you to backup all your docker volumes, images and container data.
# It also allows you to upload the backup to dropbox.
# The script is interactive, so you can choose what you want to backup.
# You can also use it in non-interactive mode, so you can use it in a cron job. (see README.md for more information)
# The script can also restore your backup, see README.md for more information.

cd "${BASH_SOURCE%/*}" || exit

# Flags
# -s: non-interactive mode
# -p: backup path
# -t: tar options
# -u: upload to dropbox
# -f: force
# -m: mode (backup or restore)


non_interactive=false
backup_path="/home/core/backups"
tar_opts="--exclude='/var/run/*'"
docker_upload_enable=false
force=false
mode=""

while getopts "sp:t:ufm:" opt; do
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
    m)
        mode=$OPTARG
        ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

# Set the backup path to absolute path if it is not
if [[ "$backup_path" != /* ]]
then
  backup_path="$PWD/$backup_path"
fi



# Setting mode $1 (need to be backup or restore)
if [ "$mode" = "backup" ]
then
  source backup/backup-all.sh
elif [ "$mode" = "restore" ]
then
  source restore/restore-all.sh
else
  echo "Invalid mode, please use backup or restore"
  exit 1
fi
