<<<<<<< HEAD
# home-backup
Temporary backup scripts for user home directories and MariaDB databases, designed as a workaround for a CWP Pro
=======
# Git-ready backup scripts

These copies are sanitized for publishing in a repository.
They are a temporary workaround for the `CWP PRO` issue in `backup_new`.
They only back up user home directories and databases; they do not include email, quotas, or CWP configuration.
Author: `idhdudu`

Edit the variables at the top of each script before use:
- `REMOTE_HOST`
- `REMOTE_PORT`
- `REMOTE_USER`
- `REMOTE_PATH`
- `LOCAL_BASE`
- `ARCHIVE_DIR_BASE`
- `MYSQL_DEFAULTS_FILE`
>>>>>>> 5a1f76f (Add backup scripts)
