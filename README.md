# Home Backup

Temporary backup scripts for user home directories and MariaDB databases, created as a workaround for a `CWP PRO` issue in `backup_new`.

This repository contains a simple backup strategy that is easy to understand, easy to automate, and easy to restore:

- user home directories are packed into `.tgz` files and sent to a remote server with `rsync`
- each database is dumped to its own `.sql.gz` file and sent to the same remote server
- backups are rotated in 7 daily slots, one for each day of the week

The scripts are designed for systems where the goal is to protect user data and databases, not the full server stack.

## What Is Included

- `/home/username` directories
- MariaDB/MySQL databases
- daily rotation with 7 slots

## What Is Not Included

- email accounts or mail data
- quotas
- CWP configuration
- full system configuration
- services outside home directories and databases

## How The Rotation Works

The scripts use `date +%u` to select a slot from `1` to `7`:

- `1` = Monday
- `2` = Tuesday
- `3` = Wednesday
- `4` = Thursday
- `5` = Friday
- `6` = Saturday
- `7` = Sunday

Each day overwrites its own slot on the remote server, so you always keep up to 7 daily copies without needing cleanup jobs on the backup server.

Example remote layout:

```text
/volume1/<hostname>/home/1
/volume1/<hostname>/home/2
/volume1/<hostname>/home/3
/volume1/<hostname>/home/4
/volume1/<hostname>/home/5
/volume1/<hostname>/home/6
/volume1/<hostname>/home/7

/volume1/<hostname>/bd/1
/volume1/<hostname>/bd/2
/volume1/<hostname>/bd/3
/volume1/<hostname>/bd/4
/volume1/<hostname>/bd/5
/volume1/<hostname>/bd/6
/volume1/<hostname>/bd/7
```

## Scripts

- `backup_home_to_rsync.sh`
  - creates one `.tgz` per user directory in `/home`
  - sends each archive with `rsync`
  - deletes the local archive only after a successful transfer

- `backup_mariadb_all_databases.sh`
  - lists the databases on the server
  - creates one `.sql.gz` per database
  - sends each archive with `rsync`
  - deletes the local archive only after a successful transfer

- `restore_home_from_tgz.sh`
  - restores home directories from `.tgz` archives
  - asks for confirmation before overwriting existing files
  - restores into `/home/username`

## Configuration

Edit the variables at the top of each script before using them:

- `REMOTE_HOST`
- `REMOTE_PORT`
- `REMOTE_USER`
- `REMOTE_PATH`
- `LOCAL_BASE`
- `ARCHIVE_DIR_BASE`
- `MYSQL_DEFAULTS_FILE`

The scripts are also prepared to fall back to the local hostname if needed.

## Requirements

- Bash
- `ssh`
- `rsync`
- `tar`
- `gzip`
- `mysqldump` or `mariadb-dump`
- `mysql` or `mariadb`

The SSH key must already be installed on the remote server so the scripts can run without a password prompt.

## Cron Setup

Use `crontab -e` as `root` and add:

```cron
MAILTO=""
30 0 * * * /opt/home-backup/backup_mariadb_all_databases.sh >> /var/log/backup_mariadb_all_databases.log 2>&1
40 0 * * * /opt/home-backup/backup_home_to_rsync.sh >> /var/log/backup_home_to_rsync.log 2>&1
```

Replace `/opt/home-backup/` with the real path where you cloned this repository.

Recommended order:

- database backup at `00:30`
- home backup at `00:40`

This gives the database backup a small head start and keeps the jobs separated.

## Restoring Home Backups

To restore home directories:

1. copy the `.tgz` files to the restore directory
2. run `restore_home_from_tgz.sh` as `root`
3. confirm the overwrite prompt

The script restores archives into `/home`, so each user lands back in `/home/username`.

## License

MIT

## Author

`idhdudu`
