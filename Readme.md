# docker backup scripts

## Description

A set of Bash scripts to back up and fully restore all your running Docker
containers: images, named volumes, bind-mounted host paths, and container
configuration.

## Requirements

- Docker
- `jq` — required for restore operations and bind-mount backup (`apt install jq` / `brew install jq`)
- Sufficient permissions to read/write bind-mount host paths (may require `sudo`)

## Flags

| Flag | Description |
|------|-------------|
| `-m` | **Required.** Mode: `backup` or `restore` |
| `-p` | Backup directory path (default: `/home/core/backups`) |
| `-t` | Extra options passed to `tar` when compressing the backup dir (e.g. `--exclude=/some/path`) |
| `-B` | Enable bind-mount backup/restore (off by default — see note below) |
| `-u` | Upload backup to Dropbox after completing |
| `-f` | Force: overwrite non-empty backup dir on backup; replace existing volumes/containers/paths on restore |
| `-s` | Non-interactive mode — skips all prompts, enables all steps (use in cron jobs) |

## What gets backed up

| Artifact | Location in backup |
|----------|--------------------|
| Container images | `<container>/<container>-image.tar` (via `docker save`) |
| Named volumes | `volumes/<volume-name>.tar.gz` — one file per volume, shared volumes deduplicated |
| Container inspect data | `<container>/<container>-data.txt` — JSON used to recreate containers on restore |
| Bind-mount host paths *(opt-in with `-B`)* | `<container>/binds/bind-N.tar.gz` + `manifest.json` |

## What gets restored (in order)

1. **Images** — `docker load` from each image tar
2. **Volumes** — extracted back into named Docker volumes
3. **Bind mounts** *(only if `-B` was used during backup)* — host paths extracted to their original locations
4. **Containers** — recreated from inspect data (best-effort: covers name, image, env, ports, volumes, restart policy, network mode)

> **Container recreation is best-effort.** Common configuration is reconstructed
> from the saved `docker inspect` output. Unusual settings (custom capabilities,
> device mappings, secrets, etc.) may need to be applied manually.

> **Bind-mount host paths** (`-v /host/path:/container/path`) require the `-B`
> flag. Without it, only the container config (the `-v` flag reference) is
> restored, but the actual host-side files are not touched. These paths often
> require root-level read/write access.

## Setup

```bash
cd docker-backup-scripts
chmod +x *.sh backup/*.sh restore/*.sh
```

## Usage

### Run a backup

```bash
./backup-manager.sh -p <output-path> -m backup
```

Include bind-mounted host paths:

```bash
./backup-manager.sh -p <output-path> -m backup -B
```

### Run a restore

```bash
./backup-manager.sh -p <backup-path> -m restore
```

Restore including bind-mounted host paths:

```bash
./backup-manager.sh -p <backup-path> -m restore -B
```

Force-replace existing containers and volumes:

```bash
./backup-manager.sh -p <backup-path> -m restore -f
```

### Backup + upload to Dropbox

```bash
./backup-manager.sh -p <output-path> -m backup -u
```

You must create a Dropbox App and place your generated access token in
`config/dropbox_uploader.conf` before using `-u`. See
https://www.dropbox.com/developers for details.

### Non-interactive / cron mode

```bash
./backup-manager.sh -p <output-path> -m backup -s
```

All steps are enabled automatically in `-s` mode (bind mounts only if `-B` is
also passed).

```bash
crontab -e
# Daily backup at midnight:
0 0 * * * /path/to/backup-manager.sh -p <output-path> -m backup -s
```

## CoreOS timer

A systemd timer for CoreOS is provided in `backup/coreos-timer/`. Run the
installation script there to set up a daily backup service.

## Testing

Two test tiers are provided.

### Unit tests — fast, no Docker daemon needed

Uses a `docker` stub to verify script logic in isolation. Requires
[bats-core](https://github.com/bats-core/bats-core) and `jq`.

```bash
bats test/*.bats
```

Covers: volume backup layout and deduplication (issue #14), dotted volume-name
parsing regression, full restore pipeline ordering (issue #18), container
reconstruction from inspect JSON, bind-mount backup/restore skip/force logic.

### Integration tests — real backup → wipe → restore → verify

Runs the full cycle inside an isolated **Docker-in-Docker** daemon so your host
containers and volumes are never touched. Requires Docker with privileged
container support.

```bash
bash test/integration/run.sh
```

Verifies end-to-end:
- Named volume data survives backup and restore
- Bind-mount host paths are backed up with `-B` and restored in place
- Container images are re-loaded after being deleted
- Restored container is running with correct env, restart policy, and port mapping
