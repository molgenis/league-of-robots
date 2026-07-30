## About

This role can create a local backup of local folder(s).

The group variables (or machine variables) use the `local_backups` for a list of
folders that needs to be backed up.

The `frequency` sublist of the `local_backups` define the frequency of backups. It can
be multiple periodical backups running at the same time on the machine (f.e. `daily`
and `weekly` backups). Per each of backup inside `local_backups`, there is a date
and time definition of when this type of backup should occur.

Cronjobs are defined and deployed, based on the naming of the backups. Make sure
that you do not deploy the backup and then redeploy it with the changed name, as  
it will result in duplicated cron jobs.

Destination of the backup folder can be also a mounted directory from the remote
server.

# Backup size growth

All the backup increments are hardlinked against last backup, in order to save  
space. The hardlinking mechanism uses rsync's internal mechanism to do so.

The cron will keep number of backups of individual folder, the oldest ones will  
be automatically deleted upon execution of the new backup.

For each `frequency` there will be one **full** copy, **plus** the differential
backups for number of `keep` backups.

## Data structure

*   Main backup folder is the main location of all the backups to be added, f.e.  
    `/backups/`
*   a subfolder inside is the name of individual backup - f.e. if we define a  
    backup of `/apps` and name it `apps` there will be  
    `/backups/apps`
*   an individual backup can have more than one frequency defined, so there will
    be a subfolder for each frequency.

## Cron execution

There is a cron call for each of the backup and for each of frequency created with
this playbook automatically. It can be viewed with `crontab -l`. The crons should
not be changed manually!

## Script procedure

1.  Script checks if the backup folders of source and destination exists.
2.  It removes the number of past backups if there is more of them than the set number.
3.  It determins the latest backup folder.
4.  It creates a new backup in `main backup > name > frequency` directory, with  
    the hardlink to the last backups of this backup type.

## Manually executing

You can also call the backup command with:

`/root/backup_cronjob.sh etc daily 10 /etc /backups/`

this will make the backup of `/etc` folder, will put the files in

`/backups/etc/daily/YYYYmmdd_HHMMSS/etc/`

and keep all together last 10 backups.

## Logging

The list of deleted folders, and the rsync entire command (before execution) is
logged into a file /root/backup_cron.sh.log (that is `${0}.log`).
The output of command also show the hardlinking of the folders, if needed for
debugging.
Log is also rotated and kept only last 1024 lines.

## Tested

With `ansible-lint v6.5.0` and `shellcheck v0.8.0`.

## Limitations

The script itself cannot be executed more than once per second. It was not yet
tested for the backups on the external machines.

Successful backup has no output. The output appears only when errors occur. In
the current configuration, the failed backup output is reported only in the mails
for the `root` user (at the moment that is in the `/var/spool/mail/root` or
`/var/mail/root`).

Do not use this backup methods for

  - the backup of the files, whose content change just slightly (f.e. appended
    new line at the end of large file (f.e. backup of large database dumps)
  - folder who has regular newly created files, that get later deleted (f.e. the
    ones in the /tmp folder)
