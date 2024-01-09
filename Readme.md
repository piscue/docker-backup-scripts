# docker backup scripts

## Description

A bunch of Bash scripts to make a backup of all your running containers
dynamically.

This will create a backup of docker images, volumes, upload to dropbox and
remove the backup files after to save space

## Setup and Usage

This script use flags for configuration. The flags are:

- **-m** to set the mode (backup or restore)
- **-b** to set the backup path
- **-t** to set the tar options
- **-u** to upload to dropbox
- **-f** to force
- **-s** to run in non-interactive mode

Also, on dropbox you must create an App to store this backups, refer to
https://www.dropbox.com/developers to get your **Generated access token**
before running it and placed inside the **config/dropbox-uploader.conf** file

Give permissions to all sh files in the folder

```bash
cd docker-backup-scripts
chmod +x *.sh
```

Run the backup

```bash
./backup-manager.sh -p <output-path> -m backup
```

Run the restoration

```bash
./backup-manager.sh -p <backup-path> -m restore
```

## Extra

Create a cron if you want to run it often (use the -s flag to run it in non-interactive mode)

```bash
crontab -e
```

```bash
0 0 * * * /path/to/backup-manager.sh -p <output-path> -m backup -s
```

For CoreOS, I supply a timer to allow run it daily with an installation script
