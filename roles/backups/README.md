# backup role

This role uses `rsync` to backup a local or remote source path to a local destination path.

The local destination folder for the backups may be

 * either a mount of a local disk/device 
 * or a mount of a network share from a remote storage server,

but you must make sure that the destination supports all the file system features used by the source path,
which may include ACLs, hard links, extend attributers, etc.

The backup schedule is managed using `cron` jobs, which use the `name` of the backup as ID.
Therefore you must make sure that the backup `name` attribute is unique and stable;
Do *not* deploy the backup and then redeploy it with a changed name,
as it will result in duplicated cron jobs.

## Backup size growth

All subsequent backups are hard linked against the most recent successful backup to save space.
The hard linking mechanism uses rsync's `link-dest` feature to do so.
Therefore all backups act as _full backup_ providing a complete _snapshot_ of the content of the source at the moment the backup was made.

## Data structure

The `backups` list must be defined for the `{{ inventory_hostname }}` that will create and store the backups.
In theory you can define it in the `host_vars` or `group_vars`, but in most cases it should be defined in tbe `static_inventory`.
For example:

```yaml
---
all:
  children:
    .....
    inventory_group_name:
      hosts:
        inventory_hostname:
          backups:
            - name: data_set # Name == ID for cronjob; don't modify after deployment!
              src: 'fully.qualified.domain.name:/path/to/source_data/'
              dest: '/path/to/fully.qualified.domain.name_backups/'
              user: name
              group: name
              keep: int            # Minimum number of successful backups to keep.
              retention_time: int  # Minimal retention time in days.
              crontab:
                minute: 0-59  # Defaults to '*' when omitted.
                hour: 0-23    # Defaults to '*' when omitted.
                day: 1-31     # Defaults to '*' when omitted.
                month: 1-12   # Defaults to '*' when omitted.
                weekday: 0-6  # Defaults to '*' when omitted.
    .....
...
```
 * `src` can be
   * `/path/to/source_data/` for a local path on the backup server.
   * `hostname:/path/to/source_data/` for a remote path starting with short `hostname` that can be resolved on the backup server.
   * `fully.qualified.domain.name:/path/to/source_data/`: for remote path starting with FQDN `hostname` that can be resolved on the backup server.
   * `another_user@hostname:/path/to/source_data/` for a remote path starting with short `hostname` that can be resolved on the backup server and where a different account name must be used to access the source data.
   * `anaother_user@fully.qualified.domain.name:/path/to/source_data/`: for remote path starting with FQDN `hostname` that can be resolved on the backup server and where a different account name must be used to access the source data.
 * The `backup` command will store the backups in `{{ dest }}/{{ name }}/` owned by `{{ user }}` in the group `{{ group }}` with
   * read-write POSIX permissions for `{{ user }}` and
   * read-only POSIX permissons for `{{ group }}` and
   * no access for others.
 * `keep` and `retention_time` work together and a sane config uses `keep / amount_of_backups_per_day = retention_time`.
   * E.g. when you want to keep 30 copies and make daily backups, then `retention_time = 30 / 1 = 30`
   * E.g. when you want to keep 30 copies and make weekly backups, then `retention_time = 30 / (1/7) = 210`
   * E.g. when you want to keep 30 copies and make 3 backups per day, then `retention_time = 30 / 3 = 10`
   * `keep` applies only to successful backups; incomplete/failed backups do not count.
   * Old backups will be deleted automatically when
     * they are older than the `retention_time`
     * and a minimum of `keep` number of backups will be left after purging the oldest ones.
   * This combination ensures that we
     * Do *not* delete young backups when `keep` was reached sooner than expected,
       because extra backups were created (manually).
     * Do *not* delete old backups when too little successful backups are left,
       when the `backup` failed for some time or the cronjob did not run at all.
 * This role will create a crontab for `{{ user }}`
   * You can inspect the created crontab using `crontab -l` executed by `{{ user }}`
   * `name` is used as a unique identifier to update cronjobs when this role is redeployed.

## Backup procedure

1. Create & check folder for the logs, which will be `/var/log/backup/{{ name }}/`.
1. Create & check destination folder.
1. Check if a `latest` symlink exists
1. Use `rsync` to create
   * either a new first backup
   * or a new subsequent backup with `--link-dest="${destination}/latest"`.
1. Update the `latest` symlink to point to the new backup if the backup completed successfully.
1. Delete outdated backups and logs.

## Manually executing

You can also call the backup command manually;
See `backup -h` for help.

## Logging

By default and when executed manually the `backup` command logs to STDOUT with verbosity specified using log levels ranging from `TRACE` to `FATAL`;
See `backup -h` for help.

The cron jobs created by this role will redirect STDOUT of the `backup` command to `/bin/logger`,
so it gets captured by the system logs in `/var/log/messages`.

## Tested

With `ansible-lint 26.6.0` and `shellcheck v0.8.0`.

## Limitations

The `backup` command cannot be executed more than once per second and per backup `src`;
Therefore it uses a lock file in `/var/log/backups/{{ name }}/` with the hashed `src` in the filename of the lock file.
When an instance of the `backup` command cannot get a lock on the lock file,
it will log a `FATAL` error and return with exit code `1`.

For backups of a remote source this role
 * will create a key pair
 * and check if the public key was added to the account used for the backups on the source machine.
 * cannot add the public key to an account management system like an LDAP
 * and will fail if the public key is not part of the list of authorized keys.

Do not use this backup methods for

  - the backup of the files, whose content change just slightly (f.e. appended
    new line at the end of large file or large database dumps).
  - folder who has regular newly created files, that get later deleted (f.e. the
    ones in the `/tmp` folder).
