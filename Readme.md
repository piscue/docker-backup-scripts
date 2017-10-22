# docker backup scripts

A bunch of bash scripts that call docker commands to make a backup of all your
running containers. Create a cron if you want to run it often.

This will create a backup of docker images, volumes, upload to dropbox and
remove the backup files after to save space

## Setup and Usage

Check inside *backup-all.sh* to set the *backup_path* to point at your current
backup folder

Give permisions to all sh files in the folder
```bash
cd docker-backup-scripts
chmod +x *.sh
```

Run the backup
```bash
./backup-all.sh
```
